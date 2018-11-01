/*
 *  AHTool.m
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import "capstone.h"
#import "keystone.h"

#import "AHTool.h"

#import "AHCleaner.h"



/*
** Defines
*/
#pragma mark - Defines

#define kOrder @"order"

#define kAssemblerArch @"asm_arch"
#define kAssemblerMode @"asm_mode"
#define kAssemblerSyntax @"asm_syntax"

#define kDisasemblerArch @"dsm_arch"
#define kDisasemblerMode @"dsm_mode"
#define kDisasemblerSyntax @"dsm_arch"



/*
** Prototypes
*/
#pragma mark - Prototypes

static NSString * hexa_from_bytes(const uint8_t *bytes, size_t size);
static NSData * data_from_hexa(NSString *hexadecimal);



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
		architectures = @{
			@"i386"		: @{ kOrder : @0,	kAssemblerArch : @(KS_ARCH_X86), kAssemblerMode : @(KS_MODE_32),	kDisasemblerArch : @(CS_ARCH_X86), kDisasemblerMode : @(CS_MODE_32) },
			@"x86_64"	: @{ kOrder : @1,	kAssemblerArch : @(KS_ARCH_X86), kAssemblerMode : @(KS_MODE_64),	kDisasemblerArch : @(CS_ARCH_X86), kDisasemblerMode : @(CS_MODE_64) },
			
			@"arm"		: @{ kOrder : @2,	kAssemblerArch : @(KS_ARCH_ARM), kAssemblerMode : @(KS_MODE_ARM),	kDisasemblerArch : @(CS_ARCH_ARM), kDisasemblerMode : @(CS_MODE_ARM) },
			@"arm-thumb": @{ kOrder : @3,	kAssemblerArch : @(KS_ARCH_ARM), kAssemblerMode : @(KS_MODE_THUMB),	kDisasemblerArch : @(CS_ARCH_ARM), kDisasemblerMode : @(CS_MODE_THUMB) },
			
			@"ppc"		: @{ kOrder : @4,	kAssemblerArch : @(KS_ARCH_PPC), kAssemblerMode : @(0),				kDisasemblerArch : @(CS_ARCH_PPC), kDisasemblerMode : @(0) },
			@"ppc64"	: @{ kOrder : @5,	kAssemblerArch : @(KS_ARCH_PPC), kAssemblerMode : @(KS_MODE_64),	kDisasemblerArch : @(CS_ARCH_PPC), kDisasemblerMode : @(CS_MODE_64) },
		};
	});

	return architectures;
}

+ (NSDictionary *)syntaxProperties
{
	static dispatch_once_t	onceToken;
	static NSDictionary		*syntaxes;
	
	dispatch_once(&onceToken, ^{
		syntaxes = @{
			@"intel"	: @{ kOrder : @0,	kAssemblerSyntax : @(KS_OPT_SYNTAX_INTEL),	kDisasemblerSyntax : @(CS_OPT_SYNTAX_INTEL) },
			@"at&t"		: @{ kOrder : @1,	kAssemblerSyntax : @(KS_OPT_SYNTAX_ATT),	kDisasemblerSyntax : @(CS_OPT_SYNTAX_ATT) },
		};
	});

	return syntaxes;
}


+ (NSArray *)architectures
{
	static dispatch_once_t	onceToken;
	static NSArray			*architectures;
	
	dispatch_once(&onceToken, ^{
		
		NSDictionary *darchirectures = [self architecturesProperties];
		
		architectures = [[darchirectures allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString * _Nonnull key1, NSString * _Nonnull key2) {
			NSNumber *order1 = darchirectures[key1][kOrder];
			NSNumber *order2 = darchirectures[key2][kOrder];
			
			return [order1 compare:order2];
		}];
	});
	
	return architectures;
}

+ (NSArray *)syntaxes
{
	static dispatch_once_t	onceToken;
	static NSArray			*syntaxes;
	
	dispatch_once(&onceToken, ^{
		
		NSDictionary *dsyntaxes = [self syntaxProperties];
		
		syntaxes = [[dsyntaxes allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString * _Nonnull key1, NSString * _Nonnull key2) {
			NSNumber *order1 = dsyntaxes[key1][kOrder];
			NSNumber *order2 = dsyntaxes[key2][kOrder];
			
			return [order1 compare:order2];
		}];
	});
	
	return syntaxes;
}



/*
** AHTool - Convertions
*/
#pragma mark - AHTool - Convertions

+ (NSString *)hexadecimalStringForASMString:(NSString *)asmString architecture:(NSString *)architecture syntax:(NSString *)syntax
{
	if (asmString.length == 0 || architecture.length == 0)
		return nil;
	
	// Fetch architecture & syntax.
	NSDictionary *darchicture = [[self architecturesProperties] objectForKey:architecture];
	NSDictionary *dsyntax = [[self syntaxProperties] objectForKey:syntax];

	if (!darchicture || !dsyntax)
		return nil;
	
	ks_arch			arch = [darchicture[kAssemblerArch] intValue];
	ks_mode			mode = [darchicture[kAssemblerMode] intValue];
	ks_opt_value	stx = [dsyntax[kAssemblerSyntax] intValue];
	
	AHCleaner *cleaner = [[AHCleaner alloc] init];

	// Create handle.
	ks_err		error;
	ks_engine	*handle = NULL;
	
	error = ks_open(arch, mode, &handle);
	
	if (error != KS_ERR_OK)
		return nil;
	
	[cleaner postponeBlock:^{
		ks_close(handle);
	}];
	
	// Set syntax.
	ks_option(handle, KS_OPT_SYNTAX, stx);
	
	// Assemble.
	uint8_t *insn = NULL;
	size_t	count;
	size_t	size;

	if (ks_asm(handle, asmString.UTF8String, 0, &insn, &size, &count) != 0)
		return nil;
	
	if (count == 0 || size == 0 || insn == NULL)
		return nil;
	
	[cleaner postponeBlock:^{
		ks_free(insn);
	}];
	
	// Create hexadecimal representation.
	NSString *assembly = hexa_from_bytes(insn, size);

	[cleaner self]; // Force ARC to keep it alive up to this point.
	
	return assembly;
}

+ (NSString *)ASMStringForHexadecimalString:(NSString *)hexaString architecture:(NSString *)architecture syntax:(NSString *)syntax
{
	if (hexaString.length == 0 || architecture.length == 0)
		return nil;
	
	// Fetch architecture & syntax.
	NSDictionary *darchicture = [[self architecturesProperties] objectForKey:architecture];
	NSDictionary *dsyntax = [[self syntaxProperties] objectForKey:syntax];
	
	if (!darchicture || !dsyntax)
		return nil;
	
	cs_arch			arch = [darchicture[kDisasemblerArch] intValue];
	cs_mode			mode = [darchicture[kDisasemblerMode] intValue];
	cs_opt_value	stx = [dsyntax[kDisasemblerSyntax] intValue];
	
	AHCleaner *cleaner = [[AHCleaner alloc] init];
	
	// Create handle.
	cs_err		error;
	__block csh	handle = 0;

	error = cs_open(arch, mode, &handle);
	
	if (error != CS_ERR_OK)
		return nil;
	
	[cleaner postponeBlock:^{
		cs_close(&handle);
	}];
	
	// Set syntax.
	cs_option(handle, CS_OPT_SYNTAX, stx);
	
	// Convert the hexa string to data.
	NSData *data = data_from_hexa(hexaString);
	
	// Disassemble.
	size_t	count;
	cs_insn	*array = NULL;
	
	count = cs_disasm(handle, data.bytes, data.length, 0, 0, &array);
	
	if (count != 1)
		return nil;

	[cleaner postponeBlock:^{
		cs_free(array, count);
	}];
	
	// Build disassembly.
	NSString *disassembly = [NSString stringWithFormat:@"%s %s", array[0].mnemonic, array[0].op_str];
	
	[cleaner self]; // Force ARC to keep it alive up to this point.

	return disassembly;
}

@end



/*
** C Tools
*/
#pragma mark - C Tools

// Switch a Hexa letter to it's numeric value
static inline uint8_t hexa_value(uint8_t value)
{
	if (value >= '0' && value <= '9')
		return (value - '0');
	else if (value >= 'A' && value <= 'F')
		return 10 + (value - 'A');
	else if (value >= 'a' && value <= 'f')
		return 10 + (value - 'a');
	else
		return value;
}

static NSString * hexa_from_bytes(const uint8_t *bytes, size_t size)
{
	// Convert the raw string to hexadecimal.
	const char	*hexa = "0123456789ABCDEF";
	char		*result_c = malloc(size * 2 + 1);
	char		*raw = result_c;
	
	if (!result_c)
		return nil;
	
	for (unsigned j = 0; j < size; j++, raw += 2)
	{
		uint8_t byte = bytes[j];
		
		raw[0] = hexa[byte / 16];
		raw[1] = hexa[byte % 16];
	}
	
	*raw = '\0';
	
	// Build string.
	return [[NSString alloc] initWithBytesNoCopy:result_c length:strlen(result_c) encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

static NSData * data_from_hexa(NSString *hexadecimal)
{
	// Convert the hexa string to raw bytes.
	const char	*hexa = [hexadecimal UTF8String];
	size_t		hexa_len = strlen(hexa);
	
	if (hexa_len == 0 || (hexa_len % 2 != 0))
		return nil;
	
	size_t	i = 0;
	size_t	len = hexa_len / 2;
	uint8_t	*buffer = malloc(len);
	
	for (i = 0; i < len; i++, hexa += 2)
		buffer[i] = hexa_value(hexa[0]) * 16 + hexa_value(hexa[1]);
	
	return [[NSData alloc] initWithBytesNoCopy:buffer length:len freeWhenDone:YES];
}
