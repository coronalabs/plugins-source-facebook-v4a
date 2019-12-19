//
//  CoronaFacebookDelegate.h
//  Plugin
//
//  Created by Alexander McCaleb on 8/4/15.
//
//

#ifndef _CoronaFacebookDelegate_H__
#define _CoronaFacebookDelegate_H__

#import "CoronaDelegate.h"

@interface CoronaFacebookDelegate : NSObject < CoronaDelegate >
@property(retain) id<CoronaRuntime> runtime;
@end

#endif // _CoronaFacebookDelegate_H__
