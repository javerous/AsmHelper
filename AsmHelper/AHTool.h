/*
 *  AHTool.h
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

#import <Foundation/Foundation.h>


/*
** AHTool
*/
#pragma mark - AHTool

@interface AHTool : NSObject

// -- Properties --
+ (NSArray *)architectures;

// -- Convertions --
+ (NSString *)hexadecimalStringForASMString:(NSString *)asmString withArchitecture:(NSString *)architecture;
+ (NSString *)ASMStringForHexadecimalString:(NSString *)hexaString withArchitecture:(NSString *)architecture;

@end
