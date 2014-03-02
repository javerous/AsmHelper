/*
 *  MainController.m
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

#import "MainController.h"

#import "AHTool.h"


/*
** MainController
*/
#pragma mark - MainController

@interface MainController ()

@property (weak, nonatomic) IBOutlet NSPopUpButton	*asmToHexaArch;
@property (weak, nonatomic) IBOutlet NSTextField	*asmToHexaInput;
@property (weak, nonatomic) IBOutlet NSTextField	*asmToHexaOutput;

@property (weak, nonatomic) IBOutlet NSPopUpButton	*hexaToAsmArch;
@property (weak, nonatomic) IBOutlet NSTextField	*hexaToAsmInput;
@property (weak, nonatomic) IBOutlet NSTextField	*hexaToAsmOutput;

- (IBAction)convertASMToHexa:(id)sender;
- (IBAction)convertHexaToASM:(id)sender;

@end



/*
** MainController
*/
#pragma mark - MainController

@implementation MainController


/*
** MainController - Life
*/
#pragma mark - MainController - Life

- (void)awakeFromNib
{
	// Build architecture list.
	NSArray *architectures = [AHTool architectures];
	
	for (NSString *architecture in architectures)
	{
		[_asmToHexaArch addItemWithTitle:architecture];
		[_hexaToAsmArch addItemWithTitle:architecture];
	}

	// Preferences.
	NSUserDefaults *pref = [NSUserDefaults standardUserDefaults];
	
	[_asmToHexaArch selectItemWithTitle:([pref objectForKey:@"a2h_arch"] ?: @"i386")];
	[_asmToHexaInput setStringValue:([pref objectForKey:@"a2h_in"] ?: @"")];
	[_asmToHexaOutput setStringValue:([pref objectForKey:@"a2h_out"] ?: @"-")];
	[_hexaToAsmArch selectItemWithTitle:([pref objectForKey:@"h2a_arch"] ?: @"i386")];
	[_hexaToAsmInput setStringValue:([pref objectForKey:@"h2a_in"] ?: @"")];
	[_hexaToAsmOutput setStringValue:([pref objectForKey:@"h2a_out"] ?: @"-")];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	NSUserDefaults *pref = [NSUserDefaults standardUserDefaults];
	
	[pref setObject:[_asmToHexaArch titleOfSelectedItem] forKey:@"a2h_arch"];
	[pref setObject:[_asmToHexaInput stringValue] forKey:@"a2h_in"];
	[pref setObject:[_asmToHexaOutput stringValue] forKey:@"a2h_out"];
	[pref setObject:[_hexaToAsmArch titleOfSelectedItem] forKey:@"h2a_arch"];
	[pref setObject:[_hexaToAsmInput stringValue] forKey:@"h2a_in"];
	[pref setObject:[_hexaToAsmOutput stringValue] forKey:@"h2a_out"];
}



/*
** MainController - IBActions
*/
#pragma mark - MainController - IBActions

- (IBAction)convertASMToHexa:(id)sender
{
	NSString *result = [AHTool hexadecimalStringForASMString:_asmToHexaInput.stringValue withArchitecture:_asmToHexaArch.titleOfSelectedItem];
	
	if (!result)
	{
		NSBeep();
		result = @"-";
	}
	
	_asmToHexaOutput.stringValue = result;
}

- (IBAction)convertHexaToASM:(id)sender
{
	NSString *result = [AHTool ASMStringForHexadecimalString:_hexaToAsmInput.stringValue withArchitecture:_hexaToAsmArch.titleOfSelectedItem];
	
	if (!result)
	{
		NSBeep();
		result = @"-";
	}
	
	_hexaToAsmOutput.stringValue = result;
}

@end
