<?php
/* vim: set expandtab tabstop=4 shiftwidth=4 softtabstop=4: */

/**
 * Source Game Events Parser
 * (C) 2016, Jared Ballou <insurgency@jballou.com>
 * Released without restriction or license
 *
 * This toll will be used to load the events.res files from gamedata. This is
 * the first building block needed to programatically generate SourceMod
 * plugins to log all game events reliably.
 *
*/
// {{{ GLOBALS

/**
 * Include VDF parser until I get a better implementation
*/
include "vdfparser.php";

// }}}
// {{{ GameEvents

/**
 * This class reads the files at the specified path and glob into an indexed
 * array of events. Files, then events, then fields in three dimensions.
*/
class GameEvents {
	// {{{ properties
	private $respath = "/home/insserver/insurgency-tools/public/data/mods/insurgency/2.2.7.3/resource";
	private $resfile = "*events.res";
	private $files = array();
	private $events = array();
	// }}}
	// {{{ __construct
	public function __construct($respath='',$resfile='') {
		if ($respath)
			$this->respath = $respath;
		if ($resfile)
			$this->resfile = $resfile;
		$this->LoadResFiles();
	}
	// }}}
	// {{{ LoadResFiles
	public function LoadResFiles() {
		$this->events = array();
		$this->files = glob("{$this->respath}/{$this->resfile}");
		foreach ($this->files as $file) {
			// TODO: Stop using array_merge during loop, especially if file count is high
			$this->events = array_merge($this->events,VDFParse($file));
		}
	}
	// }}}
	// {{{ GetEvents
	public function GetEvents() {
		return $this->events;
	}
	// }}}
}
