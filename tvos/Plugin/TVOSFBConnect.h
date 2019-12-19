// ----------------------------------------------------------------------------
// 
// TVOSFBConnect.h
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Alexander McCaleb
//
// ----------------------------------------------------------------------------

#ifndef _TVOSFBConnect_H__
#define _TVOSFBConnect_H__

#include "CoronaLua.h"
#include "FBConnect.h"
#include "FBConnectEvent.h"

#import <UIKit/UIKit.h>
//#import <AddressBook/AddressBook.h>
//#import <AddressBookUI/AddressBookUI.h>
#import <FBSDKTVOSKit/FBSDKTVOSKit.h>
#import <FBSDKShareKit/FBSDKShareKit.h>

// ----------------------------------------------------------------------------

@class NSArray;
@class NSError;
@class NSString;
@class NSURL;

@protocol CoronaRuntime;

struct lua_State;

namespace Corona
{

class FBConnectEvent;

// ----------------------------------------------------------------------------

class TVOSFBConnect : public FBConnect
{
	public:
		typedef FBConnect Super;
		typedef TVOSFBConnect Self;

	public:
		TVOSFBConnect( id< CoronaRuntime > runtime );
		virtual ~TVOSFBConnect();

	protected:
		bool Initialize( NSString *appId );

	protected:
		void LoginStateChanged( FBConnectLoginEvent::Phase state, NSError *error ) const;
		void ReauthorizationCompleted( NSError *error ) const;

	public:
		void Dispatch( const FBConnectEvent& e ) const;

	public:
		virtual int GetCurrentAccessToken( lua_State *L ) const;
		virtual void Login( const char *permissions[], int numPermissions, bool attempNativeLogin ) const;
		virtual bool IsAccessDenied() const;
		virtual void Logout() const;
		virtual void PublishInstall() const;
		virtual void Request( lua_State *L, const char *path, const char *httpMethod, int x ) const;
		virtual void ShowDialog( lua_State *L, int index ) const;

	protected:
		void LoginAppropriately( NSArray *readPermissions, NSArray *publishPermissions ) const;
		void LoginWithOnlyRequiredPermissions() const;
		void RequestPermissions( NSArray *readPermissions, NSArray *publishPermissions ) const;
//		void HandleRequestPermissionsResponse( NSArray *permissionsToVerify, FBSDKLoginManagerLoginResult *result, NSError *error ) const;

	private:
		static int CreateLuaTableFromStringArray( lua_State *L, NSArray* array );
		static bool IsPublishPermission( NSString *permission );
		static bool IsShareAction( NSString *action );
//		static FBSDKGameRequestActionType GetActionTypeFrom( NSString* actionTypeString );
//		static FBSDKGameRequestFilter GetFilterFrom( NSString* filterString );
	
	private:
		id< CoronaRuntime > fRuntime;
		id fConnectionDelegate;
		id fNoAppIdAlertDelegate;
		id fShareDialogDelegate;
		id fGameRequestDialogDelegate;
		mutable bool fHasObserver;
	
		// Facebook account management
//		FBSDKLoginManager *fLoginManager;
//		ACAccountStore *fAccountStore;
//		ACAccountType *fFacebookAccountType;
		NSString *fFacebookAppId;
	
		// Error messages
		static const char kLostAccessTokenError[];
	
		// Enum to NSString conversion dictionaries
		static NSDictionary* FBSDKGameRequestActionTypeDictionary;
		static NSDictionary* FBSDKGameRequestFilterDictionary;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

#endif // _TVOSFBConnect_H__
