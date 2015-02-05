#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>

#if AMXX_VERSION_NUM < 183
	#include <ColorChat>
	#define MAX_PLAYERS 33
	#define MAX_NAME_LENGTH 32
#endif

#pragma semicolon 1


new sz_MenuText[MAX_PLAYERS][ MAX_PLAYERS],
	num[MAX_PLAYERS], cnt[MAX_PLAYERS],
	bool:flood[MAX_PLAYERS], bool:Name[MAX_PLAYERS], bool:Admin[MAX_PLAYERS], g_szFile[128], last_pass[MAX_PLAYERS][MAX_PLAYERS];

static const Version[]     = "1.0.4a-rev",
			 Built         = 25,
			 pluginName[] = "ROM-Protect",
			 Terrorist[]   = "#Terrorist_Select",
			 CT_Select[]   = "#CT_Select",
			 cfgFile[]     = "addons/amxmodx/configs/rom_protect.cfg",
			 langFile[]    = "addons/amxmodx/data/lang/rom_protect.txt",
			 langType[]    = "%L",
			 newLine       = -1;

new loginName[1024][MAX_PLAYERS], loginPass[1024][MAX_PLAYERS], loginAccs[1024][MAX_PLAYERS], loginFlag[1024][MAX_PLAYERS];
new admin_number, bool:lang_file;

enum
{
    FM_TEAM_T = 1,
    FM_TEAM_CT,
    FM_TEAM_SPECTATOR
}

#define OFFSET_TEAM  114 
#define fm_set_user_team(%1,%2)  set_pdata_int( %1, OFFSET_TEAM, %2 )
#define fm_get_user_team(%1)     get_pdata_int( %1, OFFSET_TEAM ) 

enum _:g_Cvars
{
	Tag,
	cmd_bug,
	spec_bug,
	fake_players,
	fake_players_limit,
	admin_chat_flood,
	admin_chat_flood_time,
	advertise,
	advertise_time,
	delete_custom_hpk,
	delete_vault,
	plug_warn,
	plug_log,
	admin_login,
	admin_login_file,
	admin_login_debug,
	utf8_bom,
	color_bug,
	motdfile,
	anti_pause
	
};
new g_Cvar[g_Cvars];

new Float:g_Flooding[ MAX_PLAYERS ] = {0.0, ...},
	g_Flood[ MAX_PLAYERS ] = {0, ...};

new Trie:g_tDefaultRes;

new const char_list[ ] =
{
	'A','B','C','D','E','F','G','H',
	'I','J','K','L','M','N','O','P',
	'Q','R','S','T','U','V','W','X',
	'Y','Z','a','b','c','d','e','f',
	'g','h','i','j','k','l','m','n',
	'o','p','q','r','s','t','u','v',
	'w','x','y','z','!','@','#','$',
	'%','&','*','(',')','_','-','+',
	'=','\','|','[','{',']','}',':',
	',','<','.','>','/','?','0','1',
	'2','3','4','5','6','7','8','9'
};

enum
{
	INFO_NAME,
	INFO_IP,
	INFO_AUTHID    
};

public plugin_precache( )
	{	
	registersPrecache();
	
	new szCurentDate[ 15 ];
	get_localinfo( "amxx_configsdir", g_szFile, charsmax ( g_szFile ) );
	format( g_szFile, charsmax ( g_szFile ), "%s/%s", g_szFile, pluginName );
	
	if( !dir_exists( g_szFile ) )
		mkdir( g_szFile );
	
	get_time( "%d-%m-%Y", szCurentDate , charsmax ( szCurentDate ) );      
	format( g_szFile, charsmax( g_szFile ), "%s/%s_%s.log", g_szFile, pluginName, szCurentDate );
	
	if( !file_exists( g_szFile ) )
		{
		write_file( g_szFile, "*Aici este salvata activitatea suspecta a fiecarui jucator. ", newLine );
		write_file( g_szFile, " ", newLine );
		write_file( g_szFile, " ", newLine );
	}
	/*
	get_mapname( g_szMapName, charsmax( g_szMapName ) );
	format( g_szMapName, charsmax( g_szMapName ) , "*Harta: %s|", g_szMapName );
	*/
	
	if( file_exists( cfgFile ) )
		server_cmd( "exec %s", cfgFile );
	
	set_task(10.0, "CheckLang");
	set_task(15.0, "CheckLangFile");
	set_task(20.0, "CheckCfg");
}

public CheckCfg()
{
	if( !file_exists(cfgFile) )
		WriteCfg(false);
	else
	{
		new File = fopen( cfgFile, "r+" );
		
		new Text[ 121 ], bool:cfg_file, bool:find_search; 
		while ( !feof( File ) )
		{
			fgets( File, Text, charsmax( Text ) );
			
			if( containi(Text, Version) != -1 )
				find_search = true;
			else
			cfg_file = true;			
		}
		if(cfg_file && !find_search)
		{
			WriteCfg( true );
			cfg_file = false;
			if( getNum( g_Cvar[plug_log] ) == 1 )
				logCommand( langType, LANG_SERVER, "ROM_UPDATE_CFG", getString(g_Cvar[Tag]) );
			server_print( langType, LANG_SERVER, "ROM_UPDATE_CFG", getString(g_Cvar[Tag]) );
		}
	}
}

public CheckLang()
{
	if( !file_exists(langFile) )
		WriteLang(false);
	else
	{
		lang_file = false;
		new File = fopen( langFile, "r+" );
		
		new Text[ 121 ], bool:find_search; 
		while ( !feof( File ) )
		{
			fgets( File, Text, charsmax(Text) );
			
			if( containi(Text, Version) != -1 )
				find_search = true;
				
		}
		if(!find_search)
		{
			register_dictionary("rom_protect.txt");
			lang_file = true;
			if( getNum( g_Cvar[plug_log] ) == 1 )
				logCommand( langType, LANG_SERVER, "ROM_UPDATE_LANG", getString(g_Cvar[Tag]) );
			server_print( langType, LANG_SERVER, "ROM_UPDATE_LANG", getString(g_Cvar[Tag]) );
			WriteLang( true );
		}
	}
}

public CheckLangFile()
{
	if(!lang_file)
		register_dictionary("rom_protect.txt");
}

public plugin_init( )
{
	registersInit();
	
	if( getNum(g_Cvar[advertise] ) == 1 )
	{
		new Float:timp = get_pcvar_float(g_Cvar[advertise_time]);
		set_task(timp, "showAdvertise", _, _, _, "b", 0);
	}
	
	if( getNum( g_Cvar[ utf8_bom ] ) == 1 )
	{
		g_tDefaultRes = TrieCreate();
		TrieSetCell( g_tDefaultRes , "de_storm.res", 1); 
		TrieSetCell( g_tDefaultRes , "default.res", 1); 
		
		set_task(10.0, "cleanResFiles");
	}
	
}

public plugin_cfg( )
{   
	g_Cvar[admin_chat_flood_time] = get_cvar_pointer( "amx_flood_time" );
	
	if( !g_Cvar[admin_chat_flood_time] )
		g_Cvar[admin_chat_flood_time] = register_cvar( "rom_admin_chat_flood_time", "0.75" );
}

public client_connect( id )
{
	if( getNum( g_Cvar[cmd_bug] )  == 1 )
	{
		new name[ MAX_NAME_LENGTH ];
		get_user_name( id, name, charsmax( name ) );
		nameStringFilter( name, charsmax(name) );
		set_user_info( id, "name", name );
	}
	if ( getNum( g_Cvar[fake_players] ) == 1 )
	{
		new players[ MAX_PLAYERS -1 ], pnum, address[ MAX_PLAYERS -1 ], address2[ MAX_PLAYERS -1 ];
		if(	is_user_steam(id) )
			query_client_cvar( id, "fps_max", "checkBot" );
		get_players( players, pnum, "c" );
		for( new i; i < pnum; ++i)
		{
			get_user_ip( id, address, charsmax( address ), 1 );
			get_user_ip( players[ i ], address2, charsmax(address2), 1 );
			if( equal( address, address2 ) && !is_user_bot( id ) )
			{
				if( ++cnt[ id ] > getNum( g_Cvar[fake_players_limit] ) )
				{
					server_cmd( "addip ^"30^" ^"%s^";wait;writeip", address );
					server_print( langType, LANG_SERVER, "ROM_FAKE_PLAYERS_LOG", getString(g_Cvar[Tag]), address );
					if( getNum( g_Cvar[plug_warn] ) == 1 )
					{
						#if AMXX_VERSION_NUM < 183
							ColorChat( 0, GREY, langType, LANG_PLAYER, "ROM_FAKE_PLAYERS", '^3', getString(g_Cvar[Tag]), '^4', address );
							ColorChat( 0, GREY, langType, LANG_PLAYER, "ROM_FAKE_PLAYERS_PUNISH", '^3', getString(g_Cvar[Tag]), '^4' );
						#else
							client_print_color( 0, print_team_grey, langType, LANG_PLAYER, "ROM_FAKE_PLAYERS", getString(g_Cvar[Tag]), address );
							client_print_color( 0, print_team_grey, langType, LANG_PLAYER, "ROM_FAKE_PLAYERS_PUNISH", getString(g_Cvar[Tag]) );
						#endif
					}
					if( getNum( g_Cvar[plug_log] ) == 1 )
						logCommand( langType, LANG_SERVER, "ROM_FAKE_PLAYERS_LOG", getString(g_Cvar[Tag]), address );
					break;
				}
			}
		}
	}
}

      

public client_disconnect(id)
	{
	cnt[id] = 0;
	if( Admin[id] )
	{
		Admin[id] = false;
		remove_user_flags( id );
	}
}

public plugin_end( )
{
	if( getNum( g_Cvar[delete_vault] ) != 0 )
	{
		new g_baseDir[ 128 ];
		new text[ 200 ];
		get_basedir( g_baseDir,127 );
		format( g_baseDir,127, "%s/data/vault.ini", g_baseDir );
		if( file_exists( g_baseDir ) )
		{
			delete_file( g_baseDir );
			if( getNum( g_Cvar[delete_vault] ) == 2 )
			{
				formatex( text, charsmax(text) , "server_language ro", g_baseDir);
				write_file( g_baseDir, text , newLine );
			}
			if( getNum( g_Cvar[delete_vault] ) == 1 )
			{
				formatex( text, charsmax(text), "server_language en", g_baseDir );
				write_file( g_baseDir, text, newLine ) ;
			}
		}
	}
	if( getNum( g_Cvar[delete_custom_hpk] ) == 1 )
	{
		new szDir[] = "/", DirPointer, szFile[ 32 ];
		
		DirPointer = open_dir( szDir, "", 0 );
		
		while( next_file( DirPointer, szFile, charsmax (szFile) ) )
		{
			if(szFile[ 0 ] == '.')
				continue;
			
			if( containi( szFile, "custom.hpk" ) != -1 )
			{
				delete_file( szFile );
				break;
			}
		}
		close_dir( DirPointer );
	}
	return PLUGIN_CONTINUE;
}


public client_infochanged( id )
{
	if ( !is_user_connected( id ) )
		return PLUGIN_CONTINUE;
		
	static newname[ MAX_NAME_LENGTH ], oldname[ MAX_NAME_LENGTH ];
	get_user_name( id, oldname, charsmax( oldname ) );
	get_user_info( id, "name", newname, charsmax( newname ));
	
	if( getNum( g_Cvar[cmd_bug] )  == 1 )
	{
		nameStringFilter( newname, charsmax(newname) );
		set_user_info( id, "name", newname );
	}
	
	if ( !equal( newname, oldname ) && Admin[ id ] )
	{
		Admin[ id ] = false;
		remove_user_flags( id );
	}
	
	return PLUGIN_CONTINUE;
}

public plugin_pause()
{
	if ( getNum(g_Cvar[anti_pause]) == 1 )
	{
		server_print(langType, LANG_SERVER, "ROM_PLUGIN_PAUSE_LOG", getString(g_Cvar[Tag]) );
		if ( getNum(g_Cvar[plug_warn]) == 1)
		{
			#if AMXX_VERSION_NUM < 183
				ColorChat( 0, GREY, langType, LANG_PLAYER, "ROM_PLUGIN_PAUSE", '^3', getString(g_Cvar[Tag]), '^4' );
			#else
				client_print_color( 0, print_team_grey, langType, LANG_PLAYER, "ROM_PLUGIN_PAUSE", getString(g_Cvar[Tag]) );
			#endif
		}
		if( getNum(g_Cvar[plug_log]) == 1)
				logCommand( langType, LANG_SERVER, "ROM_PLUGIN_PAUSE_LOG", getString(g_Cvar[Tag]), getString(g_Cvar[Tag]) );
		server_cmd("amxx unpause rom_protect.amxx");
	}
}

public cmdPass( id )
{
	if( getNum( g_Cvar[admin_login] ) == 0)
		return PLUGIN_HANDLED;
	new name[ MAX_NAME_LENGTH ], pass[ 32 ];
	get_user_name( id, name, charsmax( name ) );
	read_argv( 1, pass, charsmax( pass ) );
	remove_quotes( pass );
	
	loadAdminLogin( );
	getAccess( id, pass );
	
	if(!Admin[ id ])
	{
		if(!Name[ id ])
		{
			#if AMXX_VERSION_NUM < 183
				ColorChat( id, GREY, langType, id, "ROM_ADMIN_WRONG_NAME", '^3', getString(g_Cvar[Tag]), '^4');
			#else
				client_print_color( id, print_team_grey, langType, id, "ROM_ADMIN_WRONG_NAME", getString(g_Cvar[Tag]) );
			#endif
			client_print( id, print_console, langType, id, "ROM_ADMIN_WRONG_NAME_PRINT", getString(g_Cvar[Tag]) );
		}
		else
		{
			#if AMXX_VERSION_NUM < 183
				ColorChat( id, GREY, langType, id, "ROM_ADMIN_WRONG_PASS", '^3', getString(g_Cvar[Tag]), '^4');
			#else
				client_print_color( id, print_team_grey, langType, id, "ROM_ADMIN_WRONG_PASS", getString(g_Cvar[Tag]) );
			#endif
			client_print( id, print_console, langType, id, "ROM_ADMIN_WRONG_PASS_PRINT", getString(g_Cvar[Tag]) );
		}
	}
	else
	{
		#if AMXX_VERSION_NUM < 183
			ColorChat( id, GREY, langType, id, "ROM_ADMIN_LOADED", '^3', getString(g_Cvar[Tag]), '^4');
		#else
			client_print_color( id, print_team_grey, langType, id, "ROM_ADMIN_LOADED", getString(g_Cvar[Tag]) );
		#endif
		client_print( id, print_console, langType, id, "ROM_ADMIN_LOADED_PRINT", getString(g_Cvar[Tag]) );
	}
	
	return PLUGIN_CONTINUE;
}

public hookChat(id)
{
	new said[ 192 ];
	read_args( said, charsmax( said ) );
	
	if( getNum( g_Cvar[color_bug] )  == 1 || getNum( g_Cvar[cmd_bug] ) == 1 )
	{
		new s_said[ 192 ], bool:b_said_cmd_bug[ MAX_PLAYERS ], bool:b_said_color_bug[ MAX_PLAYERS ];
		copy( s_said, charsmax( said ), said );
		for( new i = 0; i < sizeof( s_said ); ++i )
		{
			new j = i+1;
			if( getNum( g_Cvar[cmd_bug] ) == 1 && ( s_said[ i ] == '#' && isalpha(s_said[ j ]) ) || ( s_said[ i ] == '%' && s_said[ j ] == 's' ) )
			{
				b_said_cmd_bug[ id ] = true;
				break;
			}
			if( getNum( g_Cvar[color_bug] ) == 1 )
			{
				if ( s_said[i] == '' || s_said[i] == '' || s_said[i] == '' )
				{
					b_said_color_bug[ id ] = true;
					break;
				}
			}
		}
		
		if(b_said_cmd_bug[ id ])
		{
			server_print(langType, LANG_SERVER, "ROM_CMD_BUG_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ));
			if( getNum(g_Cvar[plug_warn]) == 1)
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, langType, id, "ROM_CMD_BUG", '^3', getString(g_Cvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, langType, id, "ROM_CMD_BUG", getString(g_Cvar[Tag]) );
				#endif
			}
			if( getNum(g_Cvar[plug_log]) == 1)
				logCommand(langType, LANG_SERVER, "ROM_CMD_BUG_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ));
			b_said_cmd_bug[ id ] = false;
			return PLUGIN_HANDLED;
		}
		if(b_said_color_bug[ id ])
		{
			server_print(langType, LANG_SERVER, "ROM_COLOR_BUG_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ));
			if( getNum(g_Cvar[plug_warn]) == 1)
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, langType, id, "ROM_COLOR_BUG", '^3', getString(g_Cvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, langType, id, "ROM_COLOR_BUG", getString(g_Cvar[Tag]) );
				#endif
			}
			if( getNum(g_Cvar[plug_log]) == 1)
				logCommand(langType, LANG_SERVER, "ROM_COLOR_BUG_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ));
			b_said_color_bug[ id ] = false;
			return PLUGIN_HANDLED;
		}
	}
	
	new g_said[ 2 ];
	read_argv( 1, g_said, charsmax(g_said) );
	
	if (g_said[0] != '@')
		return PLUGIN_CONTINUE;
	
	new Float:maxChat = get_pcvar_float( g_Cvar[admin_chat_flood_time] );
	
	if ( maxChat && getNum( g_Cvar[admin_chat_flood] ) == 1 )
	{
		new Float:nexTime = get_gametime( );
		
		if ( g_Flooding[ id ] > nexTime )
		{
			if  (g_Flood[ id ] >= 3 )
			{
				flood[ id ] = true;
				set_task( 1.0, "showAdminChatFloodWarning", id );
				g_Flooding[ id ] = nexTime + maxChat + 3.0;
				return PLUGIN_HANDLED;
			}
			++g_Flood[ id ];
		}
		else
		{
			if ( g_Flood[ id ] )
				--g_Flood[id];
		}
		g_Flooding[ id ] = nexTime + maxChat;
	}
	
	return PLUGIN_CONTINUE;
}

public oldStyleMenusTeammenu( msg, des, rec )
{
	if( is_user_connected( rec ) )
	{
		get_msg_arg_string ( 4, sz_MenuText[ rec ], charsmax ( sz_MenuText ) );
		if( equal( sz_MenuText[rec], Terrorist ) || equal( sz_MenuText[rec], CT_Select ))
			set_task( 0.1, "blockSpecbugOldStyleMenus", rec );
	}
}

public vGuiTeammenu( msg, des, rec )  
{  
	if(get_msg_arg_int( 1 ) == 26 || get_msg_arg_int( 1 ) == 27 )
	{
		num[ rec ] = get_msg_arg_int( 1 );
		set_task( 0.1, "blockSpecbugVGui", rec );
	}
}

public blockSpecbugOldStyleMenus( id )
{
	if( !is_user_alive( id ) && is_user_connected( id ) && getNum( g_Cvar[spec_bug] ) == 1 )
	{
		if( fm_get_user_team( id ) == FM_TEAM_SPECTATOR && !is_user_alive(id) )
		{
			if( equal( sz_MenuText[id], Terrorist ) && is_user_connected( id ) )
				fm_set_user_team( id, FM_TEAM_T );
			if( equal( sz_MenuText[id], CT_Select ) && is_user_connected( id ) )
				fm_set_user_team( id, FM_TEAM_CT );
			server_print(langType, LANG_SERVER, "ROM_SPEC_BUG_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ));
			if( getNum( g_Cvar[plug_warn] ) )
				{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, langType, id, "ROM_SPEC_BUG", '^3', getString(g_Cvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, langType, id, "ROM_SPEC_BUG", getString(g_Cvar[Tag]) );
				#endif
			}
			if( getNum( g_Cvar[plug_log] ))
				logCommand(langType, LANG_SERVER, "ROM_SPEC_BUG_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ));
		}
		set_task( 0.1, "blockSpecbugOldStyleMenus", id );
	}
}

public blockSpecbugVGui( id )
{
	new bool:bug_log[MAX_PLAYERS] = false;
	if( !is_user_alive( id ) && is_user_connected( id ) && getNum( g_Cvar[spec_bug] ) == 1 )
	{
		if(fm_get_user_team( id ) == FM_TEAM_SPECTATOR )
		{
			if(num[ id ] == 26 )
			{
				fm_set_user_team(id, FM_TEAM_T );
				bug_log[id] = true;
			}      
			if(num[ id ] == 27 )
			{
				fm_set_user_team(id, FM_TEAM_CT );
				bug_log[id] = true;
			}      
			server_print(langType, LANG_SERVER, "ROM_SPEC_BUG_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ));
			if( getNum( g_Cvar[plug_warn] ) == 1 && bug_log[id])
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, langType, id, "ROM_SPEC_BUG", '^3', getString(g_Cvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, langType, id, "ROM_SPEC_BUG", getString(g_Cvar[Tag]) );
				#endif
			}
			if( getNum( g_Cvar[plug_log] ) == 1 && bug_log[id])
			{
				logCommand(langType, LANG_SERVER, "ROM_SPEC_BUG_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ));
				bug_log[id] = false;
			}
		}
		set_task( 0.1, "blockSpecbugVGui", id );    
	}
}

public showAdminChatFloodWarning( id )
{
	if( flood[ id ] )
	{
		server_print(langType, LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ));
		if( getNum( g_Cvar[plug_warn] ) == 1 )
		{
			#if AMXX_VERSION_NUM < 183
				ColorChat( id, GREY, langType, id, "ROM_ADMIN_CHAT_FLOOD", '^3', getString(g_Cvar[Tag]), '^4');
			#else
				client_print_color( id, print_team_grey, langType, id, "ROM_ADMIN_CHAT_FLOOD", getString(g_Cvar[Tag]) );
			#endif
		}
		if( getNum( g_Cvar[plug_log] ) == 1 )
			logCommand( langType, LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ));
		flood[ id ] = false;
	}
}

public showAdvertise( id )
{
	#if AMXX_VERSION_NUM < 183
		ColorChat( id, GREY, langType, id, "ROM_ADVERTISE", '^3', getString(g_Cvar[Tag]), '^4', '^3', pluginName, '^4', '^3', Version, '^4');
	#else
		client_print_color( id, print_team_grey, langType, id, "ROM_ADVERTISE", getString(g_Cvar[Tag]), pluginName, Version );
	#endif
}

public cleanResFiles() 
	{ 
	new szMapsFolder[] = "maps"; 
	new const szResExt[] = ".res"; 
	new szResFile[64], iLen; 
	new dp = open_dir(szMapsFolder, szResFile, charsmax(szResFile)); 
	
	if( !dp ) 
		return; 
	
	new szFullPathFileName[128]; 
	do 
	{ 
		iLen = strlen(szResFile);
		if( iLen > 4 && equali(szResFile[iLen-4], szResExt) ) 
		{ 
			if( TrieKeyExists(g_tDefaultRes, szResFile) ) 
				continue;
			
			formatex(szFullPathFileName, charsmax(szFullPathFileName), "%s/%s", szMapsFolder, szResFile); 
			write_file(szFullPathFileName, "/////////////////////////////////////////////////////////////^n", 0); 
		} 
	} 
	while( next_file(dp, szResFile, charsmax(szResFile)) );
	
	close_dir(dp);
} 


public reloadLogin(id, level, cid) 
{
	set_task(1.0, "reloadDelay");
}

public reloadDelay()
{
	new players[ MAX_PLAYERS -1 ], pnum;
	get_players( players, pnum, "ch" );
	for( new i; i < pnum; ++i )
		if( Admin[ players[i] ] )
			getAccess( players[i], last_pass[ players[i] ]);
}

public cvarFunc(id, level, cid) 
{ 
	if( getNum( g_Cvar[ motdfile ] ) == 1 )
	{
		new arg[32], arg2[32]; 
		
		read_argv(1, arg, charsmax(arg));
		read_argv(2, arg2, charsmax(arg2));
		
		if( equali(arg, "motdfile") && contain(arg2, ".ini") != -1 ) 
		{
			server_print(langType, LANG_SERVER, "ROM_MOTDFILE_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ) );
			console_print(id, langType, id, "ROM_MOTDFILE", getString(g_Cvar[Tag]) );
			if( getNum( g_Cvar[plug_log] ) == 1 )
				logCommand( langType, LANG_SERVER, "ROM_MOTDFILE_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ) );
			return PLUGIN_HANDLED; 
		}
	} 
	
	return PLUGIN_CONTINUE; 
}

public checkBot( id,const szVar[], const szValue[] )
{
    if( equal(szVar, "fps_max") && szValue[0] == 'B' )
    {
		if( getNum( g_Cvar[plug_log] ) == 1 )
				logCommand( langType, LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT_LOG", getString(g_Cvar[Tag]), getInfo( id, INFO_NAME ), getInfo( id, INFO_AUTHID ), getInfo( id, INFO_IP ) );
		console_print(id, langType, id, "ROM_FAKE_PLAYERS_DETECT", getString(g_Cvar[Tag]) );
		server_cmd("kick #%d ^"You got kicked. Check console.^"",get_user_userid(id));
    }
}

loadAdminLogin( )
{
	new path[ 64 ];
	get_localinfo( "amxx_configsdir", path, charsmax( path ) );
	format( path, charsmax(path), "%s/%s", path, getString( g_Cvar [ admin_login_file ] ) );
	
	new file = fopen( path, "r+" );
	
	if ( !file )
		{
		server_print(langType, LANG_SERVER, "ROM_FILE_NOT_FOUND", getString(g_Cvar[Tag]), getString(g_Cvar[admin_login_file]) );
		if( getNum( g_Cvar[plug_log] ) == 1 )
			logCommand( langType, LANG_SERVER, "ROM_FILE_NOT_FOUND", getString(g_Cvar[Tag]), getString(g_Cvar[admin_login_file]) );
		return;
	}
	
	new text[ 121 ], name[ MAX_NAME_LENGTH ], pass[ 32 ], acc[ 26 ], flags[ 6 ];
	for ( admin_number = 0; !feof( file ); ++admin_number )
		{
		fgets( file, text, charsmax( text ) );
		
		trim( text );
		
		if( ( text[ 0 ] == ';' ) || !strlen( text ) || ( text[ 0 ] == '/' ) )
			continue;
		
		if( parse( text, name, charsmax( name ), pass, charsmax( pass ), acc, charsmax( acc ), flags, charsmax( flags ) ) != 4 )
			continue;
		
		copy( loginName[ admin_number ], charsmax( loginName[ ] ),  name );
		copy( loginPass[ admin_number ], charsmax( loginPass[ ] ),  pass );
		copy( loginAccs[ admin_number ], charsmax( loginAccs[ ] ),  acc );
		copy( loginFlag[ admin_number ], charsmax( loginFlag[ ] ),  flags );
		
		if( getNum( g_Cvar[admin_login_debug] ) == 1 )
			server_print( langType, LANG_SERVER, "ROM_ADMIN_DEBUG", loginName[ admin_number ], loginPass[ admin_number ], loginAccs[ admin_number ], loginFlag[ admin_number ] );              
	}
	fclose( file );
}

getAccess( const id, const userPass[] )
{
	static userName[ MAX_NAME_LENGTH ], acces;
	get_user_info( id, "name", userName, charsmax( userName ) );
	if( !(get_user_flags( id ) & ADMIN_CHAT ) )
		remove_user_flags( id );
	copy( last_pass[id], charsmax(last_pass[]), userPass );
	for( new i = 1; i <= admin_number; ++i )
	{
		if(  equali( loginName[ i ], userName ) )
			Name[ id ] = true;
		else
			Name[ id ] = false;
		if( equal( loginFlag[ i ], "f" ) && Name[ id ] )
		{
			if( equal( loginPass[ i ], userPass ) || Admin[ id ] )
			{
				Admin[ id ] = true;
				acces = read_flags( loginAccs[ i ] );
				set_user_flags( id, acces );
			}
			break;
		}
	}
}

logCommand( const szMsg[ ], any:... )
{
	new szMessage[ 256 ], szLogMessage[ 256 ];
	vformat( szMessage, charsmax( szMessage ), szMsg , 2 );
	
	formatex( szLogMessage, charsmax( szLogMessage ), "L %s%s", getTime( ), szMessage );
	
	write_file( g_szFile, szLogMessage, newLine );
}

getInfo( id, const iInfo )
{
	new szInfoToReturn[ 64 ];
	
	switch( iInfo )
	{
		case INFO_NAME:
		{
			static szName[ 32 ];
			get_user_name( id, szName, charsmax( szName ) );
			
			copy( szInfoToReturn, charsmax( szInfoToReturn ), szName );
		}
		case INFO_IP:
		{
			static szIp[ 32 ];
			get_user_ip( id, szIp, charsmax( szIp ), 1 );
			
			copy( szInfoToReturn, charsmax( szInfoToReturn ), szIp );
		}
		case INFO_AUTHID:
		{
			static szAuthId[ 35 ];
			get_user_authid( id, szAuthId, charsmax( szAuthId ) );
			
			copy( szInfoToReturn, charsmax( szInfoToReturn ), szAuthId );
		}
	}
	return szInfoToReturn;
}

getTime( )
{
	static szTime[ 32 ];
	get_time( " %H:%M:%S ", szTime ,charsmax( szTime ) );
	
	return szTime;
}

getString( text )
{
	static File[32]; 
	get_pcvar_string( text, File, charsmax( File ) );
	
	return File;
}

getNum( text )
{
	static num;
	num = get_pcvar_num(text);
	return num;
}

registersPrecache()
{
	g_Cvar[Tag]                   = register_cvar("rom_tag", "*ROM-Protect");
	g_Cvar[spec_bug]              = register_cvar("rom_spec-bug", "1");
	g_Cvar[admin_chat_flood]      = register_cvar("rom_admin_chat_flood", "1");
	g_Cvar[fake_players]          = register_cvar("rom_fake-players", "1");
	g_Cvar[fake_players_limit]    = register_cvar("rom_fake-players_limit", "5");
	g_Cvar[delete_custom_hpk]     = register_cvar("rom_delete_custom_hpk", "1");
	g_Cvar[delete_vault]          = register_cvar("rom_delete_vault", "1");
	g_Cvar[cmd_bug]               = register_cvar("rom_cmd-bug", "1");
	g_Cvar[advertise]             = register_cvar("rom_advertise","1");
	g_Cvar[advertise_time]        = register_cvar("rom_advertise_time", "120");
	g_Cvar[plug_warn]             = register_cvar("rom_warn", "1");
	g_Cvar[plug_log]              = register_cvar("rom_log", "1");
	g_Cvar[color_bug]             = register_cvar("rom_color-bug", "1");
	g_Cvar[admin_login]           = register_cvar("rom_admin_login", "1");
	g_Cvar[admin_login_file]      = register_cvar("rom_admin_login_file", "users_login.ini");
	g_Cvar[admin_login_debug]     = register_cvar("rom_admin_login_debug", "0");
	g_Cvar[utf8_bom]              = register_cvar("rom_utf8-bom", "1");
	g_Cvar[motdfile]              = register_cvar("rom_motdfile", "1");
	g_Cvar[anti_pause]            = register_cvar("rom_anti-pause", "1"); 
}

registersInit()
{
	register_plugin( pluginName, Version, "FioriGinal.Ro" );
	register_cvar("rom_protect", Version, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_message(get_user_msgid( "ShowMenu" ), "oldStyleMenusTeammenu");
	register_message(get_user_msgid( "VGUIMenu" ), "vGuiTeammenu");
	
	register_clcmd("say", "hookChat");
	register_clcmd("say_team", "hookChat");
	register_clcmd("login", "cmdPass" );
	register_concmd("amx_cvar", "cvarFunc");
	register_concmd("amx_reloadadmins", "reloadLogin");
}

public nameStringFilter( string[], len )
{
	for( new i; i <= len; ++i )
		if( i < MAX_NAME_LENGTH)
		{
			new j = i+1;
			if( ( string[ i ] == '#' && isalpha(string[ j ]) ) || ( string[ i ] == '+' && isalpha(string[ j ]) ) )
				string[ i ] = ' ';
		}
}

simpleStringFilter( string[], len )
{

}

bool:is_user_steam(id) 
{ 
        new authid[35];  
        get_user_authid(id, authid, charsmax(authid) );
        return contain(authid , ":") != -1 && containi(authid , "STEAM") != -1 ? true : false; 
}  

stock bool:CheckName( id )
	{
	new name[ MAX_NAME_LENGTH ];
	new contor = 0;
	new bool:b_name = false;
	get_user_info( id, "name", name, charsmax( name ) );
	//new i = 0, j = 0
	for(new i = 0 ; i <= charsmax( name ); ++i)
		{
		for(new j = 0 ; j <= charsmax( char_list ); ++j)
			{
			if( name[ i ] == char_list[ j ] )
				b_name = true;
		}
		if( b_name )
			{
			//server_print("debug 3 - %d", contor);
			++contor;
			b_name = false
		}              
		else
		{
			contor = 0
		}
		if( contor >= 3)
			{
			//server_print("debug 1 - %d", contor);
			return true;
		}
	}
	//server_print("debug 2 - %d - %d - %d", contor, i, j);
	return false;
	//isalpha(ch)
}

WriteCfg( bool:exist )
{
	if(exist)
		delete_file( cfgFile );
	new line[121];
	write_file( cfgFile, "// *ROM-Protect" , newLine );
	write_file( cfgFile, "// Plugin FREE anti-flood/bug-fix pentru orice server." , newLine );
	formatex(line, charsmax(line), "// Versiunea %s. Bulit %d", Version, Built);
	write_file( cfgFile, line , newLine ); 
	write_file( cfgFile, "// Autor : lüxor # Dr.Fio & DR2.IND (+ eNd.) - SteamID (contact) : luxxxoor" , newLine );
	write_file( cfgFile, "// O productie FioriGinal.ro - site : www.fioriginal.ro" , newLine );
	write_file( cfgFile, "// Link forum de dezvoltare : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-flood-bug-fix-t28292.html" , newLine );
	write_file( cfgFile, "// Link sursa : https://github.com/luxxxoor/ROM-Protect", -1);
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Verificare daca CFG-ul a fost executat cu succes." , newLine );
	write_file( cfgFile, "echo ^"*ROM-Protect : Fisierul rom_protect.cfg a fost gasit. Incep protejarea serverului.^"" , newLine );
	write_file( cfgFile, "// Cvar      : rom_cmd-bug" , newLine );
	write_file( cfgFile, "// Scop      : Urmareste chatul si opeste bugurile de tip ^"%s^"/^"%s0^" care dau pluginurile peste cap." , newLine );
	write_file( cfgFile, "// Impact    : Serverul nu pateste nimic, insa playerii acestuia primesc ^"quit^" indiferent de ce client folosesc, iar serverul ramane gol." , newLine );
	write_file( cfgFile, "// Update    : Incepand cu versiunea 1.0.1s, pluginul protejeaza serverele si de noul cmd-bug bazat pe caracterul '#'. Pluginul blocheaza de acum '#' si '%' in chat si '#' in nume." , newLine );
	write_file( cfgFile, "// Update    : Incepand cu versiunea 1.0.3a, pluginul devine mai inteligent, si va bloca doar posibilele folosiri ale acestui bug, astfel incat caracterele '#' si '%' vor putea fi folosite, insa nu in toate cazurile." , newLine );
	write_file( cfgFile, "// Update    : Incepand cu versiunea 1.0.3s, pluginul incearca sa inlature bugul provotat de caracterul '+' in nume, acesta incercand sa deruteze playerii sau adminii (nu aparea numele jucatorului in meniuri)." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Atacul este blocat. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_cmd-bug ^"%d^"", getNum( g_Cvar[ cmd_bug ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_cmd-bug ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_spec-bug" , newLine );
	write_file( cfgFile, "// Scop      : Urmareste activitatea playerilor si opreste schimbarea echipei, pentru a opri specbug." , newLine );
	write_file( cfgFile, "// Impact    : Serverul primeste crash in momentul in care se apeleaza la acest bug." , newLine );
	write_file( cfgFile, "// Nota      : -" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Atacul este blocat. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_spec-bug ^"%d^"", getNum( g_Cvar [ spec_bug ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_spec-bug ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_admin_chat_flood" , newLine );
	write_file( cfgFile, "// Scop      : Urmareste activitatea playerilor care folosesc chat-ul adminilor, daca persoanele incearca sa floodeze acest chat sunt opriti fortat." , newLine );
	write_file( cfgFile, "// Impact    : Serverul nu pateste nimic, insa adminii primesc kick cu motivul : ^"reliable channel overflowed^"." , newLine );
	write_file( cfgFile, "// Nota      : -" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Atacul este blocat. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_admin_chat_flood ^"%d^"", getNum( g_Cvar [ admin_chat_flood ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_admin_chat_flood ^"1^"" , newLine );
	write_file( cfgFile, "" , newLine );
	write_file( cfgFile, "// Cvar      : rom_fake-players" , newLine );
	write_file( cfgFile, "// Scop      : Urmareste persoanele conectate pe server si baneaza atunci cand numarul persoanelor cu acelasi ip il depaseste pe cel setat in cvarul rom_fake-players_limit." , newLine );
	write_file( cfgFile, "// Impact    : Serverul experimenteaza lag peste 200+ la orice jucator prezent pe server, cateodata chiar crash." , newLine );
	write_file( cfgFile, "// Nota      : Daca sunt mai multe persoane care impart aceasi legatura de internet pot fi banate ( 0 minute ), in acest caz ridicati cvarul : rom_fake-players_limit sau opriti rom_fake-players." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Atacul este blocat prin ban 30 minute. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_fake-players ^"%d^"", getNum( g_Cvar [ fake_players ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_fake-players ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_fake-players_limit ( Activat numai in cazul in care cvarul ^"rom_fake-players^" este setat pe 1 )" , newLine );
	write_file( cfgFile, "// Utilizare : Limiteaza numarul maxim de persoane de pe acelasi IP, blocand astfel atacurile tip fake-player." , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_fake-players_limit ^"%d^"", getNum( g_Cvar [ fake_players_limit ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_fake-players_limit ^"5^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_delete_custom_hpk" , newLine );
	write_file( cfgFile, "// Scop      : La finalul fiecarei harti, se va sterge fisierul custom.hpk." , newLine );
	write_file( cfgFile, "// Impact    : Serverul experimenteaza probleme la schimbarea hartii, aceasta putand sa dureze si pana la 60secunde." , newLine );
	write_file( cfgFile, "// Nota      : -" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functie este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Fisierul este sters. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_delete_custom_hpk ^"%d^"", getNum( g_Cvar [ delete_custom_hpk ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_delete_custom_hpk ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_delete_vault " , newLine );
	write_file( cfgFile, "// Scop      : La finalul fiecarei harti, se va sterge fisierul vault.ini." , newLine );
	write_file( cfgFile, "// Impact    : Serverul experimenteaza probleme la schimbarea hartii, aceasta putand sa dureze si pana la 60secunde." , newLine );
	write_file( cfgFile, "// Nota      : -" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functie este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Fisierul este sters si e setat ^"server_language en^" in vault.ini. [Default]" , newLine );
	write_file( cfgFile, "// Valoarea 2: Fisierul este sters si e setat ^"server_language ro^" in vault.ini." , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_delete_vault ^"%d^"", getNum( g_Cvar [ delete_vault ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_delete_vault ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_advertise" , newLine );
	write_file( cfgFile, "// Efect     : Afiseaza un mesaj prin care anunta clientii ca serverul este protejat de *ROM-Protect." , newLine );
	write_file( cfgFile, "// Valoarea 0: Mesajele sunt dezactivate." , newLine );
	write_file( cfgFile, "// Valoarea 1: Mesajele sunt activate. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_advertise ^"%d^"", getNum( g_Cvar [ advertise ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_advertise ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_advertise_time ( Activat numai in cazul in care cvarul ^"rom_advertise^" este setat pe 1 )" , newLine );
	write_file( cfgFile, "// Utilizare : Seteaza ca mesajul sa apara o data la (cat este setat cvarul) secunda/secunde. " , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_advertise_time ^"%d^"", getNum( g_Cvar [ advertise_time ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_advertise_time ^"120^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_warn " , newLine );
	write_file( cfgFile, "// Efect     : Afiseaza mesaje prin care anunta clientii care incearca sa distube activitatea normala a serverului. " , newLine );
	write_file( cfgFile, "// Valoarea 0: Mesajele sunt dezactivate." , newLine );
	write_file( cfgFile, "// Valoarea 1: Mesajele sunt activate. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_warn ^"%d^"", getNum( g_Cvar [ plug_warn ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_warn ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar  : rom_log" , newLine );
	write_file( cfgFile, "// Efect : Permite sau nu plugin-ului sa ne creeze fisiere.log." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Functia este activata." , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_log ^"%d^"", getNum( g_Cvar [ plug_log ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_log ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_admin_login" , newLine );
	write_file( cfgFile, "// Scop      : Permite autentificarea adminilor prin comanda ^"login parola^" in consola (nu necesita setinfo)" , newLine );
	write_file( cfgFile, "// Impact    : Parolele adminilor sunt foarte usor de furat in ziua de astazi, e destul doar sa intri pe un server iar parola ta dispare." , newLine );
	write_file( cfgFile, "// Nota      : Adminele se adauga normal ^"nume^" ^"parola^" ^"acces^" ^"f^"." , newLine );
	write_file( cfgFile, "// Update    : Incepand de la versiunea 1.0.3a, comanda in chat !login sau /login dispare, deoarece nu era folosita." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functie este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Adminele sunt protejate. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_admin_login ^"%d^"", getNum( g_Cvar [ admin_login ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_admin_login ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar  : rom_admin_login_file ( Activat numai in cazul in care cvarul ^"rom_admin_login^" este setat pe 1 )" , newLine );
	write_file( cfgFile, "// Efect : Selecteaza fisierul de unde sa fie citite adminele cu flag ^"f^"" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_admin_login_file ^"%s^"", getString( g_Cvar [ admin_login_file ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_admin_login_file ^"users_login.ini^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar  : rom_admin_login_debug ( Activat numai in cazul in care cvarul ^"rom_admin_login^" este setat pe 1 )" , newLine );
	write_file( cfgFile, "// Efect : In cazul in care adminele nu se incarca corect acesta va printa in consola serverului argumentele citite (nume - parola - acces - flag)" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functie este dezactivata. [Default]" , newLine );
	write_file( cfgFile, "// Valoarea 1: Argumentele sunt printate in consola. " , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_admin_login_debug ^"%d^"", getNum( g_Cvar [ admin_login_debug ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_admin_login_debug ^"0^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_utf8-bom" , newLine );
	write_file( cfgFile, "// Scop      : Verifica fiecare fisier .res in maps, si daca descopera caractere UTF8-BOM le elimina." , newLine );
	write_file( cfgFile, "// Impact    : Serverul da crash cu eroarea : Host_Error: PF_precache_generic_I: Bad string." , newLine );
	write_file( cfgFile, "// Nota      : Eroarea apare doar la versiunile de HLDS 6***." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functie este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Fisierul este decontaminat. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_utf8-bom ^"%d^"", getNum( g_Cvar [ utf8_bom ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_utf8-bom ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_tag " , newLine );
	write_file( cfgFile, "// Utilizare : Seteaza tag-ul pluginului. (Numele acestuia)" , newLine );
	write_file( cfgFile, "// Nota      : Incepand de la versiunea 1.0.2s, pluginul *ROM-Protect devine mult mai primitor si te lasa chiar sa ii schimbi numele." , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_tag ^"%s^"", getString( g_Cvar [ Tag ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_tag ^"*ROM-Protect^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_color-bug " , newLine );
	write_file( cfgFile, "// Scop      : Urmareste chatul si opeste bugurile de tip color-bug care alerteaza playerii si adminii." , newLine );
	write_file( cfgFile, "// Impact    : Serverul nu pateste nimic, insa playerii sau adminii vor fi alertati de culorile folosite de unul din clienti." , newLine );
	write_file( cfgFile, "// Nota      : - " , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Bug-ul este blocat. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_color-bug ^"%d^"", getNum( g_Cvar [ color_bug ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_color-bug ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_motdfile " , newLine );
	write_file( cfgFile, "// Scop      : Urmareste activitatea adminilor prin comanda amx_cvar si incearca sa opreasca modificare cvarului motdfile intr-un fisier .ini." , newLine );
	write_file( cfgFile, "// Impact    : Serverul nu pateste nimic, insa adminul care foloseste acest exploit poate fura date importante din server, precum lista de admini, lista de pluginuri etc ." , newLine );
	write_file( cfgFile, "// Nota      : Functia nu blocheaza deocamdata decat comanda amx_cvar." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Bug-ul este blocat. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_motdfile ^"%d^"", getNum( g_Cvar [ motdfile ] ));
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_motdfile ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	write_file( cfgFile, "// Cvar      : rom_anti-pause " , newLine );
	write_file( cfgFile, "// Scop      : Urmareste ca pluginul de protectie ^"ROM-Protect^" sa nu poata fi pus pe pauza de catre un raufacator." , newLine );
	write_file( cfgFile, "// Impact    : Serverul nu mai este protejat de plugin, acesta fiind expus la mai multe exploituri." , newLine );
	write_file( cfgFile, "// Nota      : -" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Bug-ul este blocat. [Default]" , newLine );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_anti-pause ^"%d^"", getNum(g_Cvar[anti_pause]) );
		write_file( cfgFile, line , newLine );
	}
	else
	write_file( cfgFile, "rom_anti-pause ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
}

WriteLang( bool:exist )
	{
	if(exist)
		delete_file( langFile );
	new line[121];
	write_file( langFile, "// *ROM-Protect" , newLine );
	write_file( langFile, "// Plugin FREE anti-flood/bug-fix pentru orice server." , newLine );
	formatex(line, charsmax(line), "// Versiunea %s. Bulit %d", Version, Built);
	write_file( langFile, line , newLine ); 
	write_file( langFile, "// Autor : lüxor # Dr.Fio & DR2.IND (+ eNd.) - SteamID (contact) : luxxxoor" , newLine );
	write_file( langFile, "// O productie FioriGinal.ro - site : www.fioriginal.ro" , newLine );
	write_file( langFile, "// Link forum de dezvoltare : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-flood-bug-fix-t28292.html" , newLine );
	write_file( langFile, "// Link sursa : https://github.com/luxxxoor/ROM-Protect", -1);
	write_file( langFile, " ", newLine );
	write_file( langFile, " ", newLine );
	write_file( langFile, " ", newLine );
	write_file( langFile, "[en]", newLine );
	write_file( langFile, " ", newLine );
	if(exist)
	{
		const eqSize = 11;
		formatex(line, charsmax(line), "ROM_UPDATE_CFG = %L", LANG_SERVER, "ROM_UPDATE_CFG", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_UPDATE_CFG = %s : Am actualizat fisierul CFG : rom_protect.cfg.", newLine );
		formatex(line, charsmax(line), "ROM_UPDATE_LANG = %L", LANG_SERVER, "ROM_UPDATE_LANG", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_UPDATE_LANG = %s : Am actualizat fisierul LANG : rom_protect.txt.", newLine );
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS = %L", LANG_SERVER, "ROM_FAKE_PLAYERS", "^%c", "^%s", "^%c"  );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_FAKE_PLAYERS = %c%s : %cS-a observat un numar prea mare de persoane de pe ip-ul : %s .", newLine );
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_PUNISH = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_PUNISH", "^%c", "^%s", "^%c", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_FAKE_PLAYERS_PUNISH = %c%s : %cIp-ul a primit ban 30 minute pentru a nu afecta jocul.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS = %L", LANG_SERVER, "ROM_FAKE_PLAYERS", "^%s"  );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_FAKE_PLAYERS = ^^3%s : ^^4S-a observat un numar prea mare de persoane de pe ip-ul : %s .", newLine );
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_PUNISH = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_PUNISH", "^%s", "^%s"  );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_FAKE_PLAYERS_PUNISH = ^^3%s : ^^4 Ip-ul a primit ban 30 minute pentru a nu afecta jocul.", newLine );
		#endif
		formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_LOG = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_LOG", "^%s", "^%s"  );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_FAKE_PLAYERS_LOG = %s : S-a depistat un atac de ^"xFake-Players^" de la IP-ul : %s .", newLine );
		formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_DETECT = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT", "^%s"  );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_FAKE_PLAYERS_DETECT = %s : Ai primit kick deoarece deoarece esti suspect de fake-client. Te rugam sa folosesti alt client.", newLine );
		formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_DETECT_LOG = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_FAKE_PLAYERS_DETECT_LOG = %s : L-am detectat pe %s [ %s | %s ] ca suspect de ^"xFake-Players^" sau ^"xSpammer^".", newLine );
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_PLUGIN_PAUSE = %L", LANG_SERVER, "ROM_PLUGIN_PAUSE", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_PLUGIN_PAUSE = %c%s : %cNe pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_PLUGIN_PAUSE = %L", LANG_SERVER, "ROM_PLUGIN_PAUSE", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_PLUGIN_PAUSE = ^^3%s : ^^4Ne pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", newLine );
		#endif
		formatex(line, charsmax(line), "ROM_PLUGIN_PAUSE_LOG = %L", LANG_SERVER, "ROM_PLUGIN_PAUSE_LOG", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_PLUGIN_PAUSE_LOG = %s : S-a depistat o incercare a opririi pluginului de protectie %s. Operatiune a fost blocata.", newLine );
		#if AMXX_VERSION_NUM < 183 
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_NAME = %L", LANG_SERVER, "ROM_ADMIN_WRONG_NAME", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_WRONG_NAME = %c%s : %cNu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_NAME = %L", LANG_SERVER, "ROM_ADMIN_WRONG_NAME", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_WRONG_NAME = ^^3%s : ^^4Nu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		#endif
		formatex(line, charsmax(line), "ROM_ADMIN_WRONG_NAME_PRINT = %L", LANG_SERVER, "ROM_ADMIN_WRONG_NAME_PRINT", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ADMIN_WRONG_NAME_PRINT = %s : Nu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_PASS = %L", LANG_SERVER, "ROM_ADMIN_WRONG_PASS", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_WRONG_PASS = %c%s : %cParola introdusa de tine este incorecta.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_PASS = %L", LANG_SERVER, "ROM_ADMIN_WRONG_PASS", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_WRONG_PASS = ^^3%s : ^^4Parola introdusa de tine este incorecta.", newLine );
		#endif
		formatex(line, charsmax(line), "ROM_ADMIN_WRONG_PASS_PRINT = %L", LANG_SERVER, "ROM_ADMIN_WRONG_PASS_PRINT", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ADMIN_WRONG_PASS_PRINT = %s : Parola introdusa de tine este incorecta.", newLine );
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADMIN_LOADED = %L", LANG_SERVER, "ROM_ADMIN_LOADED", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_LOADED = %c%s : %cAdmin-ul tau a fost incarcat.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_LOADED = %L", LANG_SERVER, "ROM_ADMIN_LOADED", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_LOADED = ^^3%s : ^^4Admin-ul tau a fost incarcat.", newLine );
		#endif
		formatex(line, charsmax(line), "ROM_ADMIN_LOADED_PRINT = %L", LANG_SERVER, "ROM_ADMIN_LOADED_PRINT", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ADMIN_LOADED_PRINT = %s : Admin-ul tau a fost incarcat.", newLine );
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_CMD_BUG = %L", LANG_SERVER, "ROM_CMD_BUG", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_CMD_BUG = %c%s : %cS-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_CMD_BUG = %L", LANG_SERVER, "ROM_CMD_BUG", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_CMD_BUG = ^^3%s : ^^4S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#endif	
		formatex(line, charsmax(line), "ROM_CMD_BUG_LOG = %L", LANG_SERVER, "ROM_CMD_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_CMD_BUG_LOG = %s : L-am detectat pe %s [ %s | %s ] ca a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.", newLine );
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_COLOR_BUG = %L", LANG_SERVER, "ROM_COLOR_BUG", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_COLOR_BUG = %c%s : %cS-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_COLOR_BUG = %L", LANG_SERVER, "ROM_COLOR_BUG", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_COLOR_BUG = ^^3%s : ^^4S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#endif
		formatex(line, charsmax(line), "ROM_COLOR_BUG_LOG = %L", LANG_SERVER, "ROM_COLOR_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_COLOR_BUG_LOG = %s : L-am detectat pe %s [ %s | %s ] ca a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.", newLine );
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_SPEC_BUG = %L", LANG_SERVER, "ROM_SPEC_BUG", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_SPEC_BUG = %c%s : %cAi facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_SPEC_BUG = %L", LANG_SERVER, "ROM_SPEC_BUG", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_SPEC_BUG = ^^3%s : ^^4Ai facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", newLine );
		#endif
		formatex(line, charsmax(line), "ROM_SPEC_BUG_LOG = %L", LANG_SERVER, "ROM_SPEC_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_SPEC_BUG_LOG = %s : L-am detectat pe %s [ %s | %s ] ca a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.", newLine );
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADMIN_CHAT_FLOOD = %L", LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_CHAT_FLOOD = %c%s : %cS-a observat un mic flood la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_CHAT_FLOOD = %L", LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_CHAT_FLOOD = ^^3%s : ^^4S-a observat un mic flood la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.", newLine );
		#endif
		formatex(line, charsmax(line), "ROM_ADMIN_CHAT_FLOOD_LOG = %L", LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ADMIN_CHAT_FLOOD_LOG = %s : L-am detectat pe %s [ %s | %s ] ca a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa dea kick adminilor de pe server.", newLine );	
		formatex(line, charsmax(line), "ROM_FILE_NOT_FOUND = %L", LANG_SERVER, "ROM_FILE_NOT_FOUND", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_FILE_NOT_FOUND = %s : Fisierul %s nu exista.", newLine );
		formatex(line, charsmax(line), "ROM_ADMIN_DEBUG = %L", LANG_SERVER, "ROM_ADMIN_DEBUG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ADMIN_DEBUG = Nume : %s - Parola : %s - Acces : %s - Flag : %s", newLine );
		formatex(line, charsmax(line), "ROM_MOTDFILE = %L", LANG_SERVER, "ROM_MOTDFILE", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_MOTDFILE = %s : S-a detectat o miscare suspecta din partea ta, comanda ta a fost blocata.", newLine );
		formatex(line, charsmax(line), "ROM_MOTDFILE_LOG = %L", LANG_SERVER, "ROM_MOTDFILE_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_MOTDFILE_LOG = %s : L-am detectat pe %s [ %s | %s ] ca a incercat sa foloseasca cvar-ul ^"motdfile^" ca sa fure informatii din acest server.", newLine );	
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADVERTISE = %L", LANG_SERVER, "ROM_ADVERTISE", "^%c", "^%s", "^%c", "^%c", "^%s", "^%c", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADVERTISE = %c%s :%c Acest server este supravegheat de pluginul de protectie %c%s%c versiunea %c%s%c .", newLine );
		#else
			formatex(line, charsmax(line), "ROM_ADVERTISE = %L", LANG_SERVER, "ROM_ADVERTISE", "^%s", "^%s", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADVERTISE = ^^3%s :^^4 Acest server este supravegheat de pluginul de protectie ^^3%s^^4 versiunea ^^3%s^^4 .", newLine );
		#endif
	}
	else
	{
		write_file( langFile, "ROM_UPDATE_CFG = %s : Am actualizat fisierul CFG : rom_protect.cfg.", newLine );
		write_file( langFile, "ROM_UPDATE_LANG = %s : Am actualizat fisierul LANG : rom_protect.txt.", newLine );
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_FAKE_PLAYERS = %c%s : %cS-a observat un numar prea mare de persoane de pe ip-ul : %s .", newLine );
			write_file( langFile, "ROM_FAKE_PLAYERS_PUNISH = %c%s : %cIp-ul a primit ban 30 minute pentru a nu afecta jocul.", newLine );
		#else
			write_file( langFile, "ROM_FAKE_PLAYERS = ^^3%s : ^^4S-a observat un numar prea mare de persoane de pe ip-ul : %s .", newLine );
			write_file( langFile, "ROM_FAKE_PLAYERS_PUNISH = ^^3%s : ^^4 Ip-ul a primit ban 30 minute pentru a nu afecta jocul.", newLine );
		#endif
		write_file( langFile, "ROM_FAKE_PLAYERS_LOG = %s : S-a depistat un atac de ^"xFake-Players^" de la IP-ul : %s .", newLine );
		write_file( langFile, "ROM_FAKE_PLAYERS_DETECT = %s : Ai primit kick deoarece deoarece esti suspect de fake-client. Te rugam sa folosesti alt client.", newLine );
		write_file( langFile, "ROM_FAKE_PLAYERS_DETECT_LOG = %s : L-am detectat pe %s [ %s | %s ] ca suspect de ^"xFake-Players^" sau ^"xSpammer^".", newLine );
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_PLUGIN_PAUSE = %c%s : %cNe pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", newLine );
		#else
			write_file( langFile, "ROM_PLUGIN_PAUSE = ^^3%s : ^^4Ne pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", newLine );
		#endif
		write_file( langFile, "ROM_PLUGIN_PAUSE_LOG = %s : S-a depistat o incercare a opririi pluginului de protectie %s. Operatiune a fost blocata.", newLine );
		#if AMXX_VERSION_NUM < 183 
			write_file( langFile, "ROM_ADMIN_WRONG_NAME = %c%s : %cNu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		#else
			write_file( langFile, "ROM_ADMIN_WRONG_NAME = ^^3%s : ^^4Nu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		#endif
		write_file( langFile, "ROM_ADMIN_WRONG_NAME_PRINT = %s : Nu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_ADMIN_WRONG_PASS = %c%s : %cParola introdusa de tine este incorecta.", newLine );
		#else
			write_file( langFile, "ROM_ADMIN_WRONG_PASS = ^^3%s : ^^4Parola introdusa de tine este incorecta.", newLine );
		#endif
		write_file( langFile, "ROM_ADMIN_WRONG_PASS_PRINT = %s : Parola introdusa de tine este incorecta.", newLine );
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_ADMIN_LOADED = %c%s : %cAdmin-ul tau a fost incarcat.", newLine );
		#else
			write_file( langFile, "ROM_ADMIN_LOADED = ^^3%s : ^^4Admin-ul tau a fost incarcat.", newLine );
		#endif
		write_file( langFile, "ROM_ADMIN_LOADED_PRINT = %s : Admin-ul tau a fost incarcat.", newLine );
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_CMD_BUG = %c%s : %cS-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#else
			write_file( langFile, "ROM_CMD_BUG = ^^3%s : ^^4S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#endif
		write_file( langFile, "ROM_CMD_BUG_LOG = %s : L-am detectat pe %s [ %s | %s ] ca a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.", newLine );
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_COLOR_BUG = %c%s : %cS-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#else
			write_file( langFile, "ROM_COLOR_BUG = ^^3%s : ^^4S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#endif
		write_file( langFile, "ROM_COLOR_BUG_LOG = %s : L-am detectat pe %s [ %s | %s ] ca a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.", newLine );
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_SPEC_BUG = %c%s : %cAi facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", newLine );
		#else
			write_file( langFile, "ROM_SPEC_BUG = ^^3%s : ^^4Ai facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", newLine );
		#endif
		write_file( langFile, "ROM_SPEC_BUG_LOG = %s : L-am detectat pe %s [ %s | %s ] ca a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.", newLine );
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_ADMIN_CHAT_FLOOD = %c%s : %cS-a observat un mic flood la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.", newLine );
		#else
			write_file( langFile, "ROM_ADMIN_CHAT_FLOOD = ^^3%s : ^^4S-a observat un mic flood la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.", newLine );
		#endif
		write_file( langFile, "ROM_ADMIN_CHAT_FLOOD_LOG = %s : L-am detectat pe %s [ %s | %s ] ca a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa dea kick adminilor de pe server.", newLine );	
		write_file( langFile, "ROM_FILE_NOT_FOUND = %s : Fisierul %s nu exista.", newLine );
		write_file( langFile, "ROM_ADMIN_DEBUG = Nume : %s - Parola : %s - Acces : %s - Flag : %s", newLine );
		write_file( langFile, "ROM_MOTDFILE = %s : S-a detectat o miscare suspecta din partea ta, comanda ta a fost blocata.", newLine );
		write_file( langFile, "ROM_MOTDFILE_LOG = %s : L-am detectat pe %s [ %s | %s ] ca a incercat sa foloseasca cvar-ul ^"motdfile^" ca sa fure informatii din acest server.", newLine );	
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_ADVERTISE = %c%s :%c Acest server este supravegheat de pluginul de protectie %c%s%c versiunea %c%s%c .", newLine );
		#else
			write_file( langFile, "ROM_ADVERTISE = ^^3%s :^^4 Acest server este supravegheat de pluginul de protectie ^^3%s^^4 versiunea ^^3%s^^4 .", newLine );
		#endif
	}
	register_dictionary("rom_protect.txt");
	lang_file = true;
}

/*
*	 Contribuitori :
* SkillartzHD : -  Metoda anti-pause plugin.
*               -  Metoda anti-xfake-player si anti-xspammer.
* COOPER :      -  Idee adaugare LANG si ajutor la introducerea acesteia in plugin.
* StefaN@CSX :  -  Gasire si reparare eroare parametrii la functia anti-xFake-Players.
*               -  Reparare compatibilitate intre functie si protocol 47.
*/
