// ----------------------------------------------------------------------------
// 
// FacebookLibrary.cpp
// Copyright (c) 2015 Corona Labs Inc. All rights reserved.
// 
// ----------------------------------------------------------------------------

#include "FacebookLibrary.h"

#include "CoronaLibrary.h"
#include "CoronaLua.h"
#include "FBConnect.h"
#include "FBConnectEvent.h"
#include <string.h>
#include <stdlib.h>

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

class FacebookLibrary
{
	public:
		typedef FacebookLibrary Self;

	public:
		static const char kName[];
		static const char kEvent[];

	protected:
		FacebookLibrary( lua_State *L );
		~FacebookLibrary();

	public:
		FBConnect *GetFBConnect() { return fFBConnect; }
		const FBConnect *GetFBConnect() const { return fFBConnect; }

	public:
		static int Open( lua_State *L );

	protected:
		static int Initialize( lua_State *L );
		static int Finalizer( lua_State *L );

	public:
		static Self *ToLibrary( lua_State *L );

	public:
		static int getCurrentAccessToken( lua_State *L );
		static int isFacebookAppEnabled( lua_State *L );
		static int login( lua_State *L );
		static int logout( lua_State *L );
		static int publishInstall( lua_State *L );
		static int request( lua_State *L );
		static int setFBConnectListener( lua_State *L );
		static int init( lua_State *L );
		static int showDialog( lua_State *L );
		static int getSDKVersion( lua_State *L );

	private:
		static int ValueForKey( lua_State *L );
		FBConnect *fFBConnect;
	
		// Error messages
		static const char kAppIdWarning[];
};

// ----------------------------------------------------------------------------

// This corresponds to the name of the library, e.g. [Lua] require "plugin.library"
const char FacebookLibrary::kName[] = "plugin.facebook.v4a";

// This corresponds to the event name, e.g. [Lua] event.name
const char FacebookLibrary::kEvent[] = "fbconnect";

// Error messages used internally
const char FacebookLibrary::kAppIdWarning[] = ": appId is no longer a required argument. This argument will be ignored.";

FacebookLibrary::FacebookLibrary( lua_State *L )
:	fFBConnect( FBConnect::New( L ) )
{
}

FacebookLibrary::~FacebookLibrary()
{
	FBConnect::Delete( fFBConnect );
}
	
int
FacebookLibrary::ValueForKey( lua_State *L )
{
	int result = 1;

	Self *library = ToLibrary( L );
	const char *key = luaL_checkstring( L, 2 );

	if ( 0 == strcmp( "isActive", key ) )
	{
		// Unlike Android, we don't have to wait for the
		// Facebook SDK to finish initializing on another thread.
		// So facebook.isActive is always true!
		lua_pushboolean( L, true );
	}
	else if ( 0 == strcmp( "accessDenied", key ) )
	{
		lua_pushboolean( L, library->GetFBConnect()->IsAccessDenied() );
	}
	else
	{
		result = 0;
	}
	
	return result;
}

int
FacebookLibrary::Open( lua_State *L )
{
	// Register __gc callback
	const char kMetatableName[] = __FILE__; // Globally unique string to prevent collision
	CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );

	// Functions in library
	const luaL_Reg kVTable[] =
	{
		{ "getCurrentAccessToken", getCurrentAccessToken },
		{ "init", init },
		{ "isFacebookAppEnabled", isFacebookAppEnabled },
		{ "login", login },
		{ "logout", logout },
		{ "publishInstall", publishInstall },
		{ "request", request },
		{ "setFBConnectListener", setFBConnectListener },
		{ "showDialog", showDialog },
		{ "getSDKVersion", getSDKVersion },

		{ NULL, NULL }
	};

	// Set library as upvalue for each library function
	Self *library = new Self( L );

	// Store the library singleton in the registry so it persists
	// using kMetatableName as the unique key.
	CoronaLuaPushUserdata( L, library, kMetatableName );
	lua_pushstring( L, kMetatableName );
	lua_settable( L, LUA_REGISTRYINDEX );

	// Leave "library" on top of stack
	// Set library as upvalue for each library function
	int result = CoronaLibraryNew( L, kName, "com.coronalabs", 1, 1, kVTable, library );
	{
		lua_pushlightuserdata( L, library );
		lua_pushcclosure( L, ValueForKey, 1 ); // pop ud
		CoronaLibrarySetExtension( L, -2 ); // pop closure
	}
	
	return result;
}

int
FacebookLibrary::Finalizer( lua_State *L )
{
	Self *library = (Self *)CoronaLuaToUserdata( L, 1 );

	library->GetFBConnect()->Finalize( L );

	delete library;

	return 0;
}

FacebookLibrary *
FacebookLibrary::ToLibrary( lua_State *L )
{
	// library is pushed as part of the closure
	Self *library = (Self *)lua_touserdata( L, lua_upvalueindex( 1 ) );
	return library;
}

// [Lua] facebook.getCurrentAccessToken()
int
FacebookLibrary::getCurrentAccessToken( lua_State *L )
{
	// Let Objective-C handle the heavy lifting, and return the table made there.
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();
	return connect->GetCurrentAccessToken( L );
}

// [Lua] facebook.init( listener )
int
FacebookLibrary::init( lua_State *L )
{
	const char functionName[] = "facebook.init()";
	
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();
	if ( FBConnectEvent::IsListener( L, 1 ) )
	{
		if (connect->GetListener() == NULL)
		{
			connect->SetListener( L, 1 );
		}
		connect->DispatchInit( L );
	}
	else
	{
		CORONA_LOG_ERROR( "%s%s", functionName, ": Please provide a listener." );
	}
	return 0;
}

// [Lua] facebook.isFacebookAppEnabled()
int
FacebookLibrary::isFacebookAppEnabled( lua_State *L )
{
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();
	
	lua_pushboolean( L, connect->IsFacebookAppEnabled() );
	
	return 1;
}
	
// [Lua] facebook.login( [listener,] [permissions] )
// TODO: Refactor facebook.login) to accept a params table.
int
FacebookLibrary::login( lua_State *L )
{
	const char functionName[] = "facebook.login()";
	
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();
	
	// Parse args if there are any
	if ( lua_gettop( L ) )
	{
		int index = 1;
		
		// Check if the deprecated login API is being used.
		int firstArgType = lua_type( L, index );
		if ( LUA_TSTRING == firstArgType || LUA_TNUMBER == firstArgType )
		{
			// Warn the user about using deprecated login API
			CORONA_LOG_WARNING( "%s%s", functionName, kAppIdWarning );
			
			// Process the remaining arguments
			index++;
		}
		
		// See if a listener was provided.
		if ( FBConnectEvent::IsListener( L, index ) )
		{
			connect->SetListener( L, index );
			index++;
		}
		
		// Check for a permissions table.
		const char **permissions = NULL;
		int numPermissions = 0;
		if ( lua_istable( L, index ) )
		{
			numPermissions = (int)lua_objlen( L, index );
			permissions = (const char **)malloc( sizeof( char*) * numPermissions );
			
			for ( int i = 0; i < numPermissions; i++ )
			{
				// Lua arrays are 1-based, so add 1 to index passed to lua_rawgeti()
				lua_rawgeti( L, index, i + 1 ); // push permissions[i]
				
				// TODO: This is broken. Cannot store pointer to value that will be popped???
				const char *value = lua_tostring( L, -1 );
				permissions[i] = value;
				lua_pop( L, 1 );
			}
			index++;
		}
		
		// TODO: Refactor native login to be part of a params table passed to facebook.login().
		// See if we want to use native login
		bool attemptNativeLogin = false;
		if ( lua_isboolean( L, index ) )
		{
			attemptNativeLogin = lua_toboolean( L, index );
		}
		
		connect->Login( permissions, numPermissions, attemptNativeLogin );
		
		if ( permissions )
		{
			free( permissions );
		}
	}
	else
	{
		// Login without arguments
		connect->Login( NULL, 0, false );
	}

	return 0;
}

// [Lua] facebook.logout()
int
FacebookLibrary::logout( lua_State *L )
{
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();

	connect->Logout();

	return 0;
}

// [Lua] facebook.publishInstall( )
int
FacebookLibrary::publishInstall( lua_State *L )
{
	const char functionName[] = "facebook.publishInstall()";
	
	if ( lua_gettop( L ) )
	{
		// Warn the user about using deprecated publishInstall API
		CORONA_LOG_WARNING( "%s%s", functionName, kAppIdWarning );
	}
	
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();
	
	connect->PublishInstall();
	
	return 0;
}

// [Lua] facebook.request( path [, httpMethod, params] )
int
FacebookLibrary::request( lua_State *L )
{
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();

	const char *path = luaL_checkstring( L, 1 );
	const char *httpMethod = ( lua_isstring( L, 2 ) ? lua_tostring( L, 2 ) : "GET" );
	connect->Request( L, path, httpMethod, 3 );

	return 0;
}

// [Lua] facebook.setFBConnectListener( listener )
int
FacebookLibrary::setFBConnectListener( lua_State *L )
{
	const char functionName[] = "facebook.setFBConnectListener()";
	
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();
	if ( FBConnectEvent::IsListener( L, 1 ) )
	{
		connect->SetListener( L, 1 );
	}
	else
	{
		CORONA_LOG_ERROR( "%s%s", functionName, ": Please provide a listener." );
	}
	return 0;
}

// [Lua] facebook.showDialog( action [, params] )
int
FacebookLibrary::showDialog( lua_State *L )
{
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();

	connect->ShowDialog( L, 1 );

	return 0;
}
int
FacebookLibrary::getSDKVersion( lua_State *L )
{
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();
	return connect->GetSDKVersion( L );
}
    
// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

CORONA_EXPORT int luaopen_plugin_facebook_v4a( lua_State *L )
{
	return Corona::FacebookLibrary::Open( L );
}
