package;

import js.html.svg.Number;
import haxe.Json;
import KeyBindings;
import js.Browser;
import haxe.ds.Option;

class PlayControl {
	public var frame:Int = 0; // Frames since level start. Inputs do happen on frame 0!
	public var paused:Bool = false; // If true, wait for frame advance to run.
	public var speed:Int = 0; // 0 for slow, 1 for normal, 2 for fast forward.
	public var silent:Bool = false; // Hide input messages on the console

	public function new() {}

	public function pause() {
		paused = true;
		speed = 0;
	}
}

class Engine {
	//var frameLengthDecimalPlaces = 8;
	var frameLength:Float = 16.66666666; // 60 FPS
	var fps:Float;

	var control = new PlayControl();
	var playback:Option<Video.VideoPlayer> = None; // If this is initialized, we're in playback.
	var recording:Video.VideoRecorder = new Video.VideoRecorder(0);
	var slots:Array<Video>;

	var fullgameVideo:Dynamic = null; // Array of multiple videos, to play several levels in one playback
	var fullgameLevelCounter:Int = 0;

	var pausedCallback:Option<Dynamic> = None;
	var _requestAnimationFrame:Dynamic;

	var initialDirection = 0; // Not needed for NoaDev games, but the parameter is needed for the Video object.

	public function new() {
		// Inject our methods into the global scope.
		_requestAnimationFrame = Browser.window.requestAnimationFrame;
		untyped window.requestAnimationFrame = this.requestAnimationFrame;

		// hook into the helper script
		untyped window.coffee = {};
		untyped window.coffee._onScene = onScene;
		untyped window.coffee._onReset = onReset;

		untyped window.coffee._keyup = this.keyup;
		untyped window.coffee._keydown = this.keydown;

		// API for runners
		untyped window.coffee.load = function(string:String, ?slot:Int) {
			if (slot == null || slot > 9 || slot < 0)
				slot = 0;
			slots[slot] = new Video(string);
		}
		untyped window.coffee.loadFullGame = function(strings:Array<String>) {
			fullgameVideo = strings.map(function(videoString) {
				return new Video(videoString);
			});

			// Run the game on normal speed, because TAS commands are disabled in "full-game" mode
			control.speed = 1;
			control.paused = false;
			triggerPausedCallback();
		}
		untyped window.coffee.clearFullGame = function() {
			fullgameVideo = null;
		}

		/*
		untyped window.coffee.useFrame = function(fl:Float) {
			frameLength = truncateFloat(fl, frameLengthDecimalPlaces);
		}
		untyped window.coffee.useFps = function(fps:Float) {
			frameLength = truncateFloat(1000.0 / fps, frameLengthDecimalPlaces);
		}
		*/

		slots = new Array();
		for (i in 0...10) {
			slots.push(new Video());
		}

		control.speed = 1;

		calculateFps();
	}

	function wrapCallback(callback:Dynamic) {
		return function() {
			switch playback {
				case Some(player):
					for (action in player.getActions(control.frame)) {
						sendGameInput(action.code, action.down);
					}
					if (control.frame + 1 >= player.video.pauseFrame) {
						// playback is over

						if (fullgameVideo == null) {
							// normally, pause at the last frame of a video
							control.pause();
							trace('[PAUSE ] @ ${control.frame + 1}');
							control.silent = false;
						} else {
							control.frame = 0;
							primeControls();
						}

						playback = None;
					}
					callback();
				case None:
					callback();
			}

			control.frame += 1;
		}
	}

	function requestAnimationFrame(callback:Dynamic) {
		var wrappedCallback = wrapCallback(callback);
		if (!control.paused) {
			switch control.speed {
				case 0:
					Browser.window.setTimeout(wrappedCallback, 100);
				case 1:
					// If the browser runs on 60, use the original requestAnimationFrame function
					if (fps >= 58 && fps <= 62)
						_requestAnimationFrame(wrappedCallback);
					// Otherwise, force the game to run on 60fps by using setTimeout
					else
						Browser.window.setTimeout(wrappedCallback, frameLength);
						
				case _:
					Browser.window.setTimeout(wrappedCallback, 0);
			}
		} else {
			pausedCallback = Some(wrappedCallback);
		}
	}

	function triggerPausedCallback() {
		switch pausedCallback {
			case Some(cb):
				pausedCallback = None;
				cb();
			case None:
				{}
		}
	}

	var keyupHandler:Dynamic;
	var keydownHandler:Dynamic;

	function keyup(callback:Dynamic) {
		keyupHandler = callback;
		Browser.window.onkeyup = function(key) {
			onKey(key, false);
		}
	}

	function keydown(callback:Dynamic) {
		keydownHandler = callback;
		Browser.window.onkeydown = function(key) {
			onKey(key, true);
		}
	}

	// Top-level for keyboard input from the user.
	function onKey(event:Dynamic, down:Bool) {
		if (!Util.isSome(playback)) {
			// We're not in playback, so we should pass through keys.
			var suppress = [83, 87, 65, 68, 82]; // prevent pressing alternate movement keys and 'r'
			if (suppress.indexOf(event.keyCode) == -1)
				sendGameInput(event.keyCode, down);
		}
		if (down && fullgameVideo == null) {
			switch (KeyBindings.fromKeyCode(event.keyCode)) {
				case Some(input):
					if (handleInterfaceInput(input, event.ctrlKey, event.altKey)) {
						event.preventDefault();
					}
				case _:
					{}
			}
		}
	}

	// Send input to the game and record it.
	function sendGameInput(keyCode:Int, down:Bool) {
		recording.recordKey(control.frame, keyCode, down, control.silent);
		var event = {
			which: keyCode, 
			key: KeyCodes.toKey(keyCode), 
			preventDefault: function() {},
			stopPropagation: function () {}
		};

		if (down) {
			keydownHandler(event);
		} else {
			keyupHandler(event);
		}
	}

	function primeControls() {
		for (code in Video.keyCodes) {
			sendGameInput(code, false);
		}
	}

	function resetLevel(?slot:Int, ?replay:Bool) {
		if (replay == null)
			replay = false;
		trace('[${replay ? "REPLAY" : "RESET to"} ${(slot == null) ? "start" : "slot " + Std.string(slot) + "..."}]');
		
		// Press the "r" key to trigger in-game reset
		sendGameInput(82, true);

		// NoaDev games requires the "r" key to be pressed during the entire frame, so we release it after 1 frame has passed.
		Browser.window.setTimeout(function() {
			sendGameInput(82, false);
		}, control.speed == 0 ? 100 : frameLength);

		recording = new Video.VideoRecorder(initialDirection);
		control = new PlayControl();
		primeControls();
	}

	function loadPlayback(video:Video) {
		playback = Some(new Video.VideoPlayer(video));
		initialDirection = video.initialDirection;
		recording = new Video.VideoRecorder(initialDirection);
	}

	// Keyboard interface.
	// Return true to signal that input was captured.
	function handleInterfaceInput(input:KeyBindings.CoffeeInput, ctrlKey:Bool, altKey:Bool):Bool {
		var oldControl = untyped JSON.parse(JSON.stringify(control));

		// stepping frames
		if (input == CoffeeInput.StepFrame && control.paused) {
			trace('[STEP  ] @ ${control.frame + 1}');
			triggerPausedCallback();
			return true;
		}

		// pausing
		if (input == CoffeeInput.Pause) {
			if (!oldControl.paused)
				trace('[PAUSE ] @ ${control.frame + 1}');
			control.pause();
			return true;
		}

		// changing playback speed
		{
			var playAction = true;
			switch (input) {
				case CoffeeInput.PlaySlow:
					control.speed = 0;
				case CoffeeInput.PlayNormal:
					control.speed = 1;
				case CoffeeInput.PlayFast:
					control.speed = 2;
				case _:
					playAction = false;
			}
			if (playAction) {
				control.paused = false;
				if (oldControl.paused)
					trace('[PLAY  ] @ ${control.frame}');
				triggerPausedCallback();
				return true;
			}
		}

		// r to reset level
		if (input == CoffeeInput.Reset) {
			playback = None;
			resetLevel();
			control.pause();
			triggerPausedCallback();
			return true;
		}

		// p to replay the video in slot 0 at normal speed
		if (input == CoffeeInput.Replay) {
			loadPlayback(slots[0]);
			resetLevel(0, true);
			control.speed = 1;
			triggerPausedCallback();
			return true;
		}

		// handling slots
		switch (input) {
			case CoffeeInput.Slot(slot):
				// replay slot
				if (!ctrlKey) {
					loadPlayback(slots[slot]);
					resetLevel(slot);
					control.speed = 2;
					if (altKey)
						control.pause();
					control.silent = true;
					triggerPausedCallback();
					return true;
				}

				// with ctrl: save slot
				if (ctrlKey && !altKey) {
					control.pause();
					var video = recording.saveVideo(control.frame);
					trace('[SAVE slot ${slot}] @ ${control.frame}');
					trace('data: ${video.toString()}');
					slots[slot] = video;
					return true;
				}
			case _:
				{}
		}
		return false;
	}

	function onScene(levelNum:Int) {
		// Function that is called when a level in the game is loaded.
		// This function is called from the game code itself.

		trace('[SCENE ${levelNum}]');

		// If we are in full game mode, prepare a video playback for the current level as the player enters it
		if (fullgameVideo != null && fullgameVideo.length >= levelNum) {
			fullgameLevelCounter = levelNum;
			loadPlayback(fullgameVideo[fullgameLevelCounter - 1]);
			control.paused = false;
			control.frame = 0;
			control.speed = 1;
			primeControls();
		}
	}

	function onReset() {
		// After the player resets a level, we want to skip the fade animation to frame zero of the level.
		// So the pause callback is triggered several times with interval. The fade takes 20 frames.
		// This function is called from the game code itself.
		var count = 0;			
		var advanceFrameInterval = Browser.window.setInterval(function(){
			triggerPausedCallback();
			count++;
			if (count >= 19) {
				// Stop the loop
				untyped clearInterval(advanceFrameInterval);
			}
		}, frameLength);
	}

	function truncateFloat(number:Float, digits:Int):Float {
		var re = new EReg("(\\d+\\.\\d{" + digits + "})(\\d)", "i");
		var isMatched = re.match(Std.string(number));
		if (isMatched){
			return Std.parseFloat(re.matched(1));
		}
		else return number;
	}

	function calculateFps() {
		// Function to calculate the browser FPS, based on how many times the "requestAnimationFrame" function runs in one second.
		// Update the FPS variable of the engine once per second

		var times = [];
		var calculatedFps;

    	function refreshLoop() {
            var now = Browser.window.performance.now();
        	while (times.length > 0 && times[0] <= now - 1000) {
            	times.shift();
        	}
        	times.push(now);
			calculatedFps = times.length;
			
			_requestAnimationFrame(refreshLoop);	
		}
		
		Browser.window.setInterval(function(){
			fps = calculatedFps;
		}, 1000);

	    refreshLoop();
	}
}
