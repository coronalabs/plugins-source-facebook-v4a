// ----------------------------------------------------------------------------
// 
// FacebookLibrary.h
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// ----------------------------------------------------------------------------

#ifndef _FacebookLibrary_H__
#define _FacebookLibrary_H__

#include "CoronaLua.h"
#include "CoronaMacros.h"

// This corresponds to the name of the library, e.g. [Lua] require "plugin.facebook.v4a"
// where the '.' is replaced with '_'
CORONA_EXPORT int luaopen_plugin_facebook_v4a( lua_State *L );

#endif // _FacebookLibrary_H__
