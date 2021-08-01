package;
import haxe.ds.Option;

enum CoffeeInput {
    StepFrame;
    Pause;
    PlaySlow;
    PlayNormal;
    PlayFast;
	Replay;
    Reset;
    Slot(code: Int);
}

class KeyBindings {
    public static function fromKeyCode(code: Int):Option<CoffeeInput> {
        switch code {
            case 90: return Some(StepFrame); // z
            case 65: return Some(Pause); // a
            case 83: return Some(PlaySlow); // s
            case 68: return Some(PlayNormal); // d
            case 70: return Some(PlayFast); // f
            case 13: return Some(Replay); // Enter
            case 82: return Some(Reset); // r
            case _: {
                if (code >= 48 && code <= 57) {
                    return Some(Slot(code - 48)); // 0-9
                } else {
                    return None;
                }
            }
        }
    }
}

class KeyCodes{
    public static function toKey(keyCode: Int):String {
        switch (keyCode){
            case 27: return "Escape";
            case 32: return " ";
            case 37: return "ArrowLeft";
            case 38: return "ArrowUp";
            case 39: return "ArrowRight";
            case 40: return "ArrowDown";
            case 65: return "a";
            case 66: return "b";
            case 67: return "c";
            case 68: return "d";
            case 69: return "e";
            case 70: return "f";
            case 71: return "g";
            case 72: return "h";
            case 73: return "i";
            case 74: return "j";
            case 75: return "k";
            case 76: return "l";
            case 77: return "m";
            case 78: return "n";
            case 79: return "o";
            case 80: return "p";
            case 81: return "q";
            case 82: return "r";
            case 83: return "s";
            case 84: return "t";
            case 85: return "u";
            case 86: return "v";
            case 87: return "w";
            case 88: return "x";
            case 89: return "y";
            case 90: return "z";
            case _: return "";
        }
    }
}