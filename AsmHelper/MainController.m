/*
 *  MainController.m
 *
 *  Copyright 2017 Avérous Julien-Pierre
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

@property (weak, nonatomic) IBOutlet NSWindow *window;

@property (weak, nonatomic) IBOutlet NSPopUpButton	*architectures;
@property (weak, nonatomic) IBOutlet NSPopUpButton	*syntaxes;

@property (weak, nonatomic) IBOutlet NSTextField	*asmToHexaInput;
@property (weak, nonatomic) IBOutlet NSTextField	*asmToHexaOutput;

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
	// Center.
	[_window center];
	
	// Build architecture list.
	NSArray *architectures = [AHTool architectures];
	
	for (NSString *architecture in architectures)
		[_architectures addItemWithTitle:architecture];
	
	// Build syntax list.
	NSArray *syntaxes = [AHTool syntaxes];
	
	for (NSString *syntax in syntaxes)
		[_syntaxes addItemWithTitle:syntax];

	// Preferences.
	NSUserDefaults *pref = [NSUserDefaults standardUserDefaults];
	
	[_architectures selectItemWithTitle:([pref objectForKey:@"architecture"] ?: @"x86_64")];
	[_syntaxes selectItemWithTitle:([pref objectForKey:@"syntax"] ?: @"at&t")];

	[_asmToHexaInput setStringValue:([pref objectForKey:@"a2h_in"] ?: @"")];
	[_asmToHexaOutput setStringValue:([pref objectForKey:@"a2h_out"] ?: @"-")];
	[_hexaToAsmInput setStringValue:([pref objectForKey:@"h2a_in"] ?: @"")];
	[_hexaToAsmOutput setStringValue:([pref objectForKey:@"h2a_out"] ?: @"-")];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	NSUserDefaults *pref = [NSUserDefaults standardUserDefaults];
	
	[pref setObject:[_architectures titleOfSelectedItem] forKey:@"architecture"];
	[pref setObject:[_syntaxes titleOfSelectedItem] forKey:@"syntax"];

	[pref setObject:[_asmToHexaInput stringValue] forKey:@"a2h_in"];
	[pref setObject:[_asmToHexaOutput stringValue] forKey:@"a2h_out"];
	[pref setObject:[_hexaToAsmInput stringValue] forKey:@"h2a_in"];
	[pref setObject:[_hexaToAsmOutput stringValue] forKey:@"h2a_out"];
}



/*
** MainController - IBActions
*/
#pragma mark - MainController - IBActions

- (IBAction)convertASMToHexa:(id)sender
{
	NSString *result = [AHTool hexadecimalStringForASMString:_asmToHexaInput.stringValue architecture:_architectures.titleOfSelectedItem syntax:_syntaxes.titleOfSelectedItem];
	
	if (!result)
	{
		NSBeep();
		result = @"-";
	}
	
	_asmToHexaOutput.stringValue = result;
}

- (IBAction)convertHexaToASM:(id)sender
{
	NSString *result = [AHTool ASMStringForHexadecimalString:_hexaToAsmInput.stringValue architecture:_architectures.titleOfSelectedItem syntax:_syntaxes.titleOfSelectedItem];
	
	if (!result)
	{
		NSBeep();
		result = @"-";
	}
	
	_hexaToAsmOutput.stringValue = result;
}

@end
