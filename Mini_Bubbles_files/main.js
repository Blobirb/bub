window._unlockingAllLevels = true;
window._allLevelsUnlocked = false;

function unlockAllLevels(){
    window._unlockingAllLevels = true;
}

window.addEventListener("load", function(){
    var __extends = document.getElementById("gameFrame").contentWindow.__extends;
    var Engine = document.getElementById("gameFrame").contentWindow.Engine;
    var Game = document.getElementById("gameFrame").contentWindow.Game;

    Game.STRONG_TOUCH_MUTE_CHECK = false;

    try{
        Game.apiEnabled = typeof parent !== 'undefined' && typeof parent.cmgGameEvent !== 'undefined';
    }
    catch(e){
        Game.apiEnabled = false;
    }

    var Intro = /** @class */ (function (_super) {
        __extends(Intro, _super);

        var removeBodyElement = function(id){
            var elem = document.getElementById(id);
            return elem.parentNode.removeChild(elem);
        }

        function Intro(){
            var _this = _super.call(this) || this;
            
            //_this.createMap("None", "Sky None");
            var x = Game.Scene.xSizeLevel * 0.5;
            var y = Game.Scene.ySizeLevel * 0.5;
            Engine.Renderer.camera(x, y);

            Engine.System.nextSceneClass = Game.MainMenu;

            Game.SceneColors.enabledDown = false;
            
            return _this;
        }
        Intro.prototype.onReset = function(){
            _super.prototype.onReset.call(this);
            Game.SceneFade.speed = 0;
        };
        Intro.prototype.onStepUpdate = function(){
            _super.prototype.onStepUpdate.call(this);
        };
        return Intro;
    }(Game.Scene));

    
    //Game.addPath("load", PATH_SPLASH);
    Game.addAction("postinit", function(){
        Game.startingSceneClass = Intro;
        Game.HAS_LINKS = false;
        Game.HAS_LINKS_NOADEV = false;
        Game.FORCE_EDGE_TUTORIAL = true;
    });

    Game.addAction("start", function(){
        var levelUnlocker = {};
        levelUnlocker.owner = null;
        levelUnlocker.preserved = true;
        levelUnlocker.onStepUpdate = function(){
            if(!window._allLevelsUnlocked && window._unlockingAllLevels){
                Game.LevelSelection.unlockAllLevels();
                window._allLevelsUnlocked = true;
                levelUnlocker.preserved = false;
            }
        };
        Engine.System.addListenersFrom(levelUnlocker);
    });

    Game.addAction("playbutton", function(){
        if(Game.apiEnabled){
            parent.cmgGameEvent("start");
        }
        else{
            console.log("start");
        }
    });
    Game.addAction("playlevelbutton", function(){
        if(Game.apiEnabled){
            parent.cmgGameEvent("start", Game.Level.nextIndex + "");
        }
        else{
            console.log("start " + Game.Level.nextIndex);
        }
    });
    Game.addAction("resetlevelbutton", function(){
        if(Game.apiEnabled){
            parent.cmgGameEvent("replay", Game.Level.index + "");
        }
        else{
            console.log("replay " + Game.Level.index);
        }
    });

    Engine.System.run();
});