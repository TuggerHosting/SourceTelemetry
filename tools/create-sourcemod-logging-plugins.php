<?php
include_once "class.SourcemodEvents.php";

$script = '#include <sourcemod>

#define PLUGIN_AUTHOR "Jared Ballou (jballou)"
#define PLUGIN_DESCRIPTION "Game Event Logging"
#define PLUGIN_LOG_PREFIX "GE"
#define PLUGIN_NAME "[INS] Game Event Logging"
#define PLUGIN_URL ""
#define PLUGIN_VERSION "0.0.1"
#define PLUGIN_WORKING "1"

public Plugin:myinfo = {
        name            = PLUGIN_NAME,
        author          = PLUGIN_AUTHOR,
        description     = PLUGIN_DESCRIPTION,
        version         = PLUGIN_VERSION,
        url             = PLUGIN_URL
};

';

function ActionEventFieldType($type,$format='code') {
	$res = array();
	switch ($type) {
		case "short":
		case "long":
		case "byte":
			$res['code'] = "Int";
			$res['log'] = "%d";
			break;
		case "bool":
			$res['code'] = "Bool";
			$res['log'] = "%d";
			break;
		case "float":
			$res['code'] = "Float";
			$res['log'] = "%f";
			break;
		case "string":
			$res['code'] = "String";
			$res['log'] = "%s";
			break;
		default:
			$res['code'] = "UNKNOWN";
			$res['log'] = "%s";
	}
	return $res[$format];
}

function ActionEventField($field,$type,$format='code') {
	$ctype = ActionEventFieldType($type,'code');
	$code = array();
	$pf="";
	$var_name = "i_{$field}";
	switch ($type) {
		case "float":
			$pf="Float:";
		case "short":
		case "long":
		case "byte":
		case "bool":
			$code[] = "\tnew {$pf}{$var_name} = GetEvent{$ctype}(event, \"{$field}\");";
			break;
		case "string":
			$code[] = "\tdecl String:{$var_name}[256];";
			$code[] = "\tGetEventString(event, \"{$field}\", {$var_name}, sizeof({$var_name}));";
			break;
		default:
			$code[] = "// Unable to process {$type} {$field}";
	}
	return implode($code,"\n");
}
function HookEvent($name,$fields) {
	$code = "\tHookEvent(\"{$name}\", Event_{$name});";
	return $code;
}
function ActionEvent($name,$fields) {
	$code = array("public Action:Event_{$name}(Handle:event, const String:name[], bool:dontBroadcast) {");
	$log = "\tLogToGame(\"[EVENT] triggered \\\"{$name}\\\"";
	$log_fields = array();
	foreach ($fields as $fieldpack => $type) {
		$field = explode("::",$fieldpack)[1];
		$log_fields[] = ", i_{$field}";
		$log.=" {$field} \\\"".ActionEventFieldType($type,'log')."\\\"";
		$code[] = ActionEventField($field,$type,'code');
	}
	$code[] = $log."\"".implode($log_fields).");";
//."\"".implode(array_keys($fields),",")
//	$log = "\tLogToGame(\"[EVENT] triggered \\\"{$name}\\\""
//	$code[]= $lc."\",".implode(
// client, player_userid, player_authid, g_team_list[player_team_index]);
//#define KILL_REGEX_PATTERN "^\"(.+(?:<[^>]*>))\" killed \"(.+(?:<[^>]*>))\" with \"([^\"]*)\" at (.*)"
//#define SUICIDE_REGEX_PATTERN "^\"(.+(?:<[^>]*>))\" committed suicide with \"([^\"]*)\""

	$code[] = "}";
	return implode($code,"\n")."\n";
	return $code;
}

function ParseEvents() {
	$se = new SourcemodEvents();
	$events = $se->GetEvents();
	$hookevents_code = array("public OnPluginStart() {");
	$actionevents_code = array();

	foreach ($events as $file) {
		foreach ($file as $name => $fields) {
			$hookevents_code[$name] = HookEvent($name,$fields);
			$actionevents_code[$name] = ActionEvent($name,$fields);
		}
	}
	$hookevents_code[] = "}";
	echo $GLOBALS['script'];
	echo implode($hookevents_code,"\n")."\n\n";
	echo implode($actionevents_code,"\n");
}

ParseEvents();

