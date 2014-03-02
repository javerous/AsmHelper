/*
 *  AHTool.m
 *
 *  Copyright 2014 Avérous Julien-Pierre
 *
 *  This file is part of AsmHelper.
 *
 *  AsmHelper is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  AsmHelper is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with AsmHelper.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>
#include <mach-o/nlist.h>
#include <mach-o/arch.h>

#import "AHTool.h"

#import "AHCleaner.h"


/*
** Defines
*/
#pragma mark - Defines

#define kArchitectureBigEndian	@"big_endian"
#define kArchitectureCPUType	@"cpu_type"
#define kArchitectureCPUSubType	@"cpu_subtype"



/*
** Prototypes
*/
#pragma mark - Prototypes

static unsigned	value_to_native(unsigned value, int isBigEndian);
static unsigned	native_to_value(unsigned native, int isBigEndian);
static uint8_t	hexa_value(uint8_t value);



/*
** AHTool
*/
#pragma mark - AHTool

@implementation AHTool


/*
** AHTool - Properties
*/
#pragma mark - AHTool - Properties

+ (NSDictionary *)architecturesProperties
{
	static dispatch_once_t	onceToken;
	static NSDictionary		*architectures;
	
	dispatch_once(&onceToken, ^{
		
		architectures = @{	@"i386"		: @{ kArchitectureBigEndian : @NO, kArchitectureCPUType : @(CPU_TYPE_X86), kArchitectureCPUSubType : @(CPU_SUBTYPE_386) },
							@"x86_64"	: @{ kArchitectureBigEndian : @NO, kArchitectureCPUType : @(CPU_TYPE_X86_64), kArchitectureCPUSubType : @(CPU_SUBTYPE_386) } ,

							@"arm"		: @{ kArchitectureBigEndian : @NO, kArchitectureCPUType : @(CPU_TYPE_ARM), kArchitectureCPUSubType : @(CPU_SUBTYPE_ARM_ALL) },

							@"ppc"		: @{ kArchitectureBigEndian : @YES, kArchitectureCPUType : @(CPU_TYPE_POWERPC), kArchitectureCPUSubType : @(CPU_SUBTYPE_POWERPC_ALL) },
							
						   // @"ppc64" : @{ kArchitectureBigEndian : @NYES },
						   };
	});

	return architectures;
}

+ (NSArray *)architectures
{
	static dispatch_once_t	onceToken;
	static NSArray			*architectures;
	
	dispatch_once(&onceToken, ^{
		architectures = [[[self architecturesProperties] allKeys] sortedArrayUsingSelector:@selector(compare:)];
	});
	
	return architectures;
}



/*
** AHTool - Convertions
*/
#pragma mark - AHTool - Convertions

+ (NSString *)hexadecimalStringForASMString:(NSString *)asmString withArchitecture:(NSString *)architecture
{
	if ([asmString length] == 0 || [architecture length] == 0)
		return nil;
	
	AHCleaner	*cleaner = [[AHCleaner alloc] init];
	
	NSDictionary	*archProperties = [[self architecturesProperties] objectForKey:architecture];
	BOOL			isBigEndian = [[archProperties objectForKey:kArchitectureBigEndian] boolValue];
	
	// Create in / out path.
	NSString	*inPath = [self temporaryPath];
	NSString	*outPath = [self temporaryPath];
	
	[cleaner postponeBlock:^{
		[[NSFileManager defaultManager] removeItemAtPath:inPath error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];
	}];

	// Write the input file.
	__block FILE *inFile = fopen([inPath fileSystemRepresentation], "w");
	
	if (!inFile)
		return nil;
	
	[cleaner postponeBlock:^{
		if (inFile)
			fclose(inFile);
	}];
	
	if (fprintf(inFile, "%s\n", [asmString UTF8String]) == 0)
		return nil;
	
	fclose(inFile);
	inFile = NULL;

	// Call 'as' to compile this asm text to Mach-O file.
	NSTask *task = [[NSTask alloc] init];
		
	[task setLaunchPath:@"/usr/bin/as"];
	[task setArguments:@[ inPath, @"-o", outPath, @"-arch", architecture ]];
		
	@try {
		[task launch];
	}
	@catch (NSException *exception) {
		return nil;
	}
	
	[task waitUntilExit];

	// Stat the Mach-O file to get it's size.
	struct stat sb;
	
	if (stat([outPath fileSystemRepresentation], &sb) != 0)
		return nil;
	
	// Open the Mach-O to map it in memory.
	__block int fd = open([outPath fileSystemRepresentation], O_RDONLY);
	
	if (fd < 0)
		return nil;
	
	[cleaner postponeBlock:^{
		if (fd > 0)
			close(fd);
	}];

	// Map the Mach-O file in memory
	void *image = mmap(NULL, sb.st_size, PROT_READ, MAP_FILE | MAP_PRIVATE, fd, 0);
	
	if (!image || image == MAP_FAILED)
		return nil;
	
	[cleaner postponeBlock:^{
		if (image)
			munmap(image, sb.st_size);
	}];
	
	// Parse the Mach-O file to search the TEXT section.
	const char	*hexa = "0123456789ABCDEF";
	uint32_t	*magic = (uint32_t *)image;
	
	if (*magic == MH_MAGIC || *magic == MH_CIGAM)
	{
		struct mach_header	*header = (struct mach_header *)image;
		struct load_command	*lc = (struct load_command *)((char *)header + sizeof(struct mach_header));
		unsigned			i;
		
		unsigned ncmds = value_to_native(header->ncmds, isBigEndian);
		unsigned cmdsize = value_to_native(lc->cmdsize, isBigEndian);
		
		for (i = 0; i < ncmds; i++, lc = (struct load_command *)((char *)lc + cmdsize))
		{
			unsigned cmd = value_to_native(lc->cmd, isBigEndian);
			
			if (cmd == LC_SEGMENT)
			{
				struct segment_command	*segheader = (struct segment_command*)lc;
				struct section			*sec = (struct section *)((void *)segheader + sizeof(struct segment_command));
				
				if (strcmp(sec->segname, SEG_TEXT) == 0 && strcmp(sec->sectname, SECT_TEXT) == 0)
				{
					unsigned offset = value_to_native(sec->offset, isBigEndian);
					unsigned size = value_to_native(sec->size, isBigEndian);
					
					if (offset + size <= sb.st_size)
					{
						char *buffer = malloc(size);
						
						if (!buffer)
							return nil;
						
						[cleaner postponeBlock:^{ free(buffer); }];
						
						// Copy the text section
						memcpy(buffer, image + offset, size);
						
						// Convert the buffer as un human-hexa string
						char *result_c = malloc(size * 2 + 1);
						
						if (!result_c)
							return nil;
						
						unsigned	j;
						char		*raw = result_c;
						
						for (j = 0; j < size; j++, raw += 2)
						{
							unsigned char byte = buffer[j];
							
							raw[0] = hexa[byte / 16];
							raw[1] = hexa[byte % 16];
						}
						
						*raw = '\0';
						
						// Build cocoa string.
						return [[NSString alloc] initWithBytesNoCopy:result_c length:strlen(result_c) encoding:NSASCIIStringEncoding freeWhenDone:YES];
					}
				}
			}
		}
	}
	else if (*magic == MH_MAGIC_64 || *magic == MH_CIGAM_64)
	{
		struct mach_header_64	*header = (struct mach_header_64 *)image;
		struct load_command		*lc = (struct load_command *)((char *)header + sizeof(struct mach_header_64));
		unsigned				i;
		
		unsigned ncmds = value_to_native(header->ncmds, isBigEndian);
		unsigned cmdsize = value_to_native(lc->cmdsize, isBigEndian);
		
		for (i = 0; i < ncmds; i++, lc = (struct load_command *)((char *)lc + cmdsize))
		{
			unsigned cmd = value_to_native(lc->cmd, isBigEndian);
			
			if (cmd == LC_SEGMENT_64)
			{
				struct segment_command_64	*segheader = (struct segment_command_64 *)lc;
				struct section_64			*sec = (struct section_64 *)((void *)segheader + sizeof(struct segment_command_64));
				
				if (strcmp(sec->segname, SEG_TEXT) == 0 && strcmp(sec->sectname, SECT_TEXT) == 0)
				{
					unsigned offset = value_to_native(sec->offset, isBigEndian);
					unsigned size = value_to_native((uint32_t)sec->size, isBigEndian);
					
					if (offset + size <= sb.st_size)
					{
						char *buffer = malloc(size);
						
						if (!buffer)
							return nil;
						
						[cleaner postponeBlock:^{ free(buffer); }];

						// Copy the text section
						memcpy(buffer, image + offset, size);
						
						// Convert the buffer as un human-hexa string
						char *result_c = malloc(size * 2 + 1);
						
						if (!result_c)
							return nil;
						
						unsigned	j;
						char		*raw = result_c;
						
						for (j = 0; j < size; j++, raw += 2)
						{
							unsigned char byte = buffer[j];
							
							raw[0] = hexa[byte / 16];
							raw[1] = hexa[byte % 16];
						}
						
						*raw = '\0';
						
						// Build cocoa string.
						return [[NSString alloc] initWithBytesNoCopy:result_c length:strlen(result_c) encoding:NSASCIIStringEncoding freeWhenDone:YES];
					}
				}
			}
		}
	}

	[cleaner self]; // Force ARC to keep it alive up to this point.
	
	return nil;
}

+ (NSString *)ASMStringForHexadecimalString:(NSString *)hexaString withArchitecture:(NSString *)architecture
{
	if ([hexaString length] == 0 || [architecture length] == 0)
		return nil;
	
	AHCleaner *cleaner = [[AHCleaner alloc] init];

	// Prepare regexp.
	static dispatch_once_t		onceToken;
	static 	NSRegularExpression	*regexp;
	
	dispatch_once(&onceToken, ^{
		regexp = [NSRegularExpression regularExpressionWithPattern:@"0+\t+([^\t\n]*)\t*([^\t\n]*)\n(.*)" options:0 error:nil];
	});
	
	// Get architecture properties.
	NSDictionary	*archProperties = [[self architecturesProperties] objectForKey:architecture];
	BOOL			isBigEndian;
	
	if (!archProperties)
		return nil;
	
	isBigEndian = [[archProperties objectForKey:kArchitectureBigEndian] boolValue];

	// -- Create Mach-O file --
	// Convert the hexa string to raw bytes.
	const char	*hexa = [hexaString UTF8String];
	size_t		hexa_len = strlen(hexa);
	
	if (hexa_len == 0 || (hexa_len % 2 != 0))
		return nil;
	
	size_t	i = 0;
	size_t	len = hexa_len / 2;
	uint8_t	*buffer = alloca(len);
	
	for (i = 0; i < len; i++, hexa += 2)
		buffer[i] = hexa_value(hexa[0]) * 16 + hexa_value(hexa[1]);
	
	// Build the Mach-O header.
	struct mach_header header;
	
	header.cputype =	native_to_value([archProperties[kArchitectureCPUType] unsignedIntValue], isBigEndian);
	header.cpusubtype =	native_to_value([archProperties[kArchitectureCPUSubType] unsignedIntValue], isBigEndian);
	
	header.filetype =	native_to_value(1, isBigEndian);
	header.flags =		native_to_value(0, isBigEndian);
	header.magic =		native_to_value(MH_MAGIC, isBigEndian);
	header.ncmds =		native_to_value(1, isBigEndian);
	header.sizeofcmds =	native_to_value(0, isBigEndian); // Will be fixed later.
	
	// Build the segment_command
	struct segment_command	segheader;
	unsigned				cmdsize = sizeof(struct segment_command) + sizeof(struct section);
	unsigned				offset = sizeof(struct mach_header) + cmdsize;
	
	segheader.cmd = native_to_value(LC_SEGMENT, isBigEndian);
	segheader.cmdsize = native_to_value(cmdsize, isBigEndian);
	memset(segheader.segname, 0, sizeof(segheader.segname));
	segheader.vmaddr = native_to_value(0, isBigEndian);
	segheader.vmsize = native_to_value((uint32_t)len, isBigEndian);
	segheader.fileoff = native_to_value(offset, isBigEndian);
	segheader.filesize = native_to_value((uint32_t)len, isBigEndian);
	segheader.maxprot = native_to_value(7, isBigEndian);
	segheader.initprot = native_to_value(7, isBigEndian);
	segheader.nsects = native_to_value(1, isBigEndian);
	segheader.flags = native_to_value(0, isBigEndian);
	
	// Fix mach_header.
	header.sizeofcmds =	native_to_value(cmdsize, isBigEndian);
	
	// Build the section.
	struct section	sec;
	
	memset(&sec, 0, sizeof(struct section));
	
	strcpy(sec.sectname, SECT_TEXT);
	strcpy(sec.segname, SEG_TEXT);
	
	sec.addr = native_to_value(0, isBigEndian);
	sec.size = native_to_value((uint32_t)len, isBigEndian);
	sec.offset = native_to_value(offset, isBigEndian);
	sec.align = native_to_value(0, isBigEndian);
	sec.reloff = native_to_value(0, isBigEndian);
	sec.nreloc = native_to_value(0, isBigEndian);
	sec.flags = native_to_value(S_REGULAR | S_ATTR_PURE_INSTRUCTIONS, isBigEndian);
	sec.reserved1 = native_to_value(0, isBigEndian);
	sec.reserved2 = native_to_value(0, isBigEndian);
	
	// Generate temporary path.
	NSString *outPath = [self temporaryPath];
	
	[cleaner postponeBlock:^{
		[[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];
	}];

	// Write the Mach-O file from the structures.
	__block FILE *outFile = fopen([outPath fileSystemRepresentation], "w");
	
	if (!outFile)
		return nil;
	
	[cleaner postponeBlock:^{
		if (outFile)
			fclose(outFile);
	}];
	
	if (fwrite(&header, sizeof(struct mach_header), 1, outFile) == 0)
		return nil;
	
	if (fwrite(&segheader, sizeof(struct segment_command), 1, outFile) == 0)
		return nil;
	
	if (fwrite(&sec, sizeof(struct section), 1, outFile) == 0)
		return nil;
	
	if (fwrite(buffer, len, 1, outFile) == 0)
		return nil;
	
	// Write a padding with zeros.
	size_t padding = 4 - (len % 4);
	
	if (padding > 0 && padding < 4)
	{
		size_t	i;
		uint8_t	zero = 0;
		
		for (i = 1; i <= padding; i++)
			fwrite(&zero, 1, 1, outFile);
	}
	
	fclose(outFile);
	outFile = NULL;
	
	
	// -- Disassemble --
	// Configure task for otool.
	NSTask	*task = [[NSTask alloc] init];
	NSPipe	*pipe = [[NSPipe alloc] init];
	
	[task setLaunchPath:@"/usr/bin/otool"];
	[task setArguments:@[@"-t", @"-v", @"-arch", architecture, outPath]];
	[task setStandardOutput:pipe];
	
	// Launch the task and get output.
	@try {
		[task launch];
	}
	@catch (NSException *exception) {
		return nil;
	}
	
	[task waitUntilExit];

	// Parse output.
	NSFileHandle *handle = [pipe fileHandleForReading];
	NSString	*outData = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
	NSArray		*matches = [regexp matchesInString:outData options:0 range:NSMakeRange(0, [outData length])];
	NSTextCheckingResult *checking;
	
	// > Check the match.
	if ([matches count] == 0)
		return nil;
	
	checking = matches[0];

	// > Check the ranges.
	if ([checking numberOfRanges] != 4)
		return nil;
	
	// > Check that there is no extra lines (error dectection).
	if ([checking rangeAtIndex:3].length != 0)
		return nil;
	
	// > Build result.
	NSString	*operator = [outData substringWithRange:[checking rangeAtIndex:1]];
	NSString	*operand = [outData substringWithRange:[checking rangeAtIndex:2]];
	NSString	*result;
	
	if ([operand length])
		result = [NSString stringWithFormat:@"%@ %@", operator, operand];
	else
		result = [NSString stringWithFormat:@"%@", operator];
	
	[cleaner self];  // Force ARC to keep it alive up to this point.
	
	return result;
}



/*
** AHTool - Helpers
*/
#pragma mark - AHTool - Helpers

+ (NSString *)temporaryPath
{
	NSString	*tempTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"asmhelper_XXXXXXXX"];
	char		*cTempTemplate = strdup([tempTemplate fileSystemRepresentation]);
	
	if (mktemp(cTempTemplate) == NULL)
	{
		free(cTempTemplate);
		
		return nil;
	}
	else
	{
		return [[NSString alloc] initWithBytesNoCopy:cTempTemplate length:strlen(cTempTemplate) encoding:NSUTF8StringEncoding freeWhenDone:YES];
	}
}

@end



/*
** C Tools
*/
#pragma mark - C Tools

// Convert a value in big or little endian in native endianness
static unsigned value_to_native(unsigned value, int isBigEndian)
{
	if (isBigEndian)
		return EndianU32_BtoN(value);
	else
		return EndianU32_LtoN(value);
}

// Convert a value in native endianness in big or little endian
static unsigned native_to_value(unsigned native, int isBigEndian)
{
	if (isBigEndian)
		return EndianU32_NtoB(native);
	else
		return EndianU32_NtoL(native);
}

// Switch a Hexa letter to it's numeric value
static uint8_t hexa_value(uint8_t value)
{
	if (value >= '0' && value <= '9')
		return (value - '0');
	else if (value >= 'A' && value <= 'F')
		return 10 + (value - 'A');
	else if (value >= 'a' && value <= 'f')
		return (value - 'a');
	else
		return value;
}
