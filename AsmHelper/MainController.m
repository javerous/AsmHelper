/*
 *  MainController.m
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

#import "MainController.h"

#import "AHTool.h"


/*
** MainController
*/
#pragma mark - MainController

@interface MainController () <NSControlTextEditingDelegate>
{
	BOOL _continuousAsmToHexa;
	BOOL _continuousHexaToAsm;
}

@property (weak, nonatomic) IBOutlet NSWindow *window;

@property (weak, nonatomic) IBOutlet NSPopUpButton	*architectures;
@property (weak, nonatomic) IBOutlet NSPopUpButton	*syntaxes;

@property (weak, nonatomic) IBOutlet NSButton 		*asmToHexaButton;
@property (weak, nonatomic) IBOutlet NSTextField	*asmToHexaInput;
@property (weak, nonatomic) IBOutlet NSTextField	*asmToHexaOutput;

@property (weak, nonatomic) IBOutlet NSButton		*hexaToAsmButton;
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
	
	_continuousAsmToHexa = [[pref objectForKey:@"continuousAsmToHexa"] boolValue];
	_continuousHexaToAsm = [[pref objectForKey:@"continuousHexaToAsm"] boolValue];

	if (_continuousAsmToHexa)
	{
		_asmToHexaButton.buttonType = NSButtonTypePushOnPushOff;
		_asmToHexaButton.state = NSControlStateValueOn;
	}
	
	if (_continuousHexaToAsm)
	{
		_hexaToAsmButton.buttonType = NSButtonTypePushOnPushOff;
		_hexaToAsmButton.state = NSControlStateValueOn;
	}
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
	// Handle toggle.
	[self handleToogleForButton:sender prefName:@"continuousAsmToHexa" boolValue:&_continuousAsmToHexa];

	// Convert.
	[self convertASMToHexa];
}

- (IBAction)convertHexaToASM:(id)sender
{
	// Handle toggle.
	[self handleToogleForButton:sender prefName:@"continuousHexaToAsm" boolValue:&_continuousHexaToAsm];
	
	// Convert.
	[self convertHexaToASM];
}

- (IBAction)changeArchitecture:(id)sender
{
	if (_continuousAsmToHexa)
		[self convertASMToHexa];

	if (_continuousHexaToAsm)
		[self convertHexaToASM];
}

- (IBAction)changeSyntax:(id)sender
{
	if (_continuousAsmToHexa)
		[self convertASMToHexa];
	
	if (_continuousHexaToAsm)
		[self convertHexaToASM];
}



/*
** MainController - NSControl
*/
#pragma mark - MainController - NSControl

- (void)controlTextDidChange:(NSNotification *)obj
{
	NSTextField *changedField = obj.object;
	
	if (changedField == _asmToHexaInput)
	{
		if (_continuousAsmToHexa)
			[self convertASMToHexa];
	}
	else if (changedField == _hexaToAsmInput)
	{
		if (_continuousHexaToAsm)
			[self convertHexaToASM];
	}
}



/*
** MainController - Helpers
*/
#pragma mark - MainController - Helpers

- (void)handleToogleForButton:(NSButton *)button prefName:(NSString *)prefName boolValue:(BOOL *)boolValue
{
	if (NSApplication.sharedApplication.currentEvent.modifierFlags & NSEventModifierFlagOption)
	{
		*boolValue = ! *boolValue;
		
		if (*boolValue)
		{
			button.buttonType = NSButtonTypePushOnPushOff;
			button.state = NSControlStateValueOn;
		}
		else
		{
			button.buttonType = NSButtonTypeMomentaryPushIn;
			button.state = NSControlStateValueOff;
		}
		
		[[NSUserDefaults standardUserDefaults] setBool:*boolValue forKey:prefName];
	}
	else
	{
		if (*boolValue)
		{
			*boolValue = NO;
			
			button.buttonType = NSButtonTypeMomentaryPushIn;
			button.state = NSControlStateValueOff;
			
			[[NSUserDefaults standardUserDefaults] setBool:*boolValue forKey:prefName];
		}
	}
}

- (void)convertASMToHexa
{
	NSString *result = [AHTool hexadecimalStringForASMString:_asmToHexaInput.stringValue architecture:_architectures.titleOfSelectedItem syntax:_syntaxes.titleOfSelectedItem];
	
	if (!result)
		result = @"-";
	
	_asmToHexaOutput.stringValue = result;
}

- (void)convertHexaToASM
{
	NSString *result = [AHTool ASMStringForHexadecimalString:_hexaToAsmInput.stringValue architecture:_architectures.titleOfSelectedItem syntax:_syntaxes.titleOfSelectedItem];
	
	if (!result)
		result = @"-";
	
	_hexaToAsmOutput.stringValue = result;
}



@end
