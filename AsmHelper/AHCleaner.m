/*
 *  AHCleaner.m
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

#import "AHCleaner.h"

/*
** AHCleaner - Private
*/
#pragma mark - AHCleaner - Private

@interface AHCleaner ()
{
	dispatch_queue_t	_localQueue;
	NSMutableArray		*_blocks;
}

@end



/*
** AHCleaner
*/
#pragma mark - AHCleaner

@implementation AHCleaner

/*
** AHCleaner - Instance
*/
#pragma mark - AHCleaner - Instance

- (id)init
{
    self = [super init];
	
    if (self)
	{
        _localQueue = dispatch_queue_create("com.sourcemac.asmhelper.ahcleaner.local", DISPATCH_QUEUE_SERIAL);
		_blocks = [[NSMutableArray alloc] init];
    }
	
    return self;
}

- (void)dealloc
{
	for (dispatch_block_t block in _blocks)
		block();
}



/*
** AHCleaner - Content
*/
#pragma mark - AHCleaner - Content

- (void)postponeBlock:(dispatch_block_t)block
{
	if (!block)
		return;
	
	dispatch_async(_localQueue, ^{
		[_blocks addObject:block];
	});
}

@end
