//
//  CoronaFacebookDelegate.m
//  Plugin
//
//  Created by Alexander McCaleb on 8/4/15.
//
//

#import "CoronaFacebookDelegate.h"
#import "CoronaRuntime.h"
#import "CoronaDelegate.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>


@implementation CoronaFacebookDelegate

- (void)willLoadMain:(id<CoronaRuntime>)runtime
{
}

- (void)didLoadMain:(id<CoronaRuntime>)runtime
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive.
	// If the application was previously in the background, optionally refresh the user interface.
	// TODO: NOT FORCE THIS DOWN DEVELOPER'S THROATS AS WE LET THEM OPT-IN WITH PUBLISHINSTALL ON BOTH PLATFORMS!
	[FBSDKAppEvents activateApp];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	return [[FBSDKApplicationDelegate sharedInstance] application:application
									didFinishLaunchingWithOptions:launchOptions];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
	return [[FBSDKApplicationDelegate sharedInstance] application:application
														  openURL:url
												sourceApplication:sourceApplication
													   annotation:annotation];
}

-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
	return [[FBSDKApplicationDelegate sharedInstance] application:app openURL:url options:options];
}

@end
