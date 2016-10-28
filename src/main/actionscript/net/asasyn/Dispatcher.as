package net.asasyn {
public class Dispatcher {
    public function Dispatcher() {
    }
    private var listeners:Vector.<Function> = null;


    public function add(func:Function):void {
        if (listeners == null) {
            listeners = new <Function>[];
        }
        listeners.push(func);
    }


    public function dispatch(...values):void {
        if (listeners == null) {
            return;
        }

        for each(var func:Function in listeners) {
            func.apply(null, values);
        }
    }

    public function removeAll():void {
        listeners = null;
    }
}
}
