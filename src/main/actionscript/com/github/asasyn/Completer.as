package com.github.asasyn {


/**
 * 非同期処理の完了を通知するためのユーテリティクラス
 */
public class Completer {

    private var _future:CompleterFuture;

    public function Completer() {
        _future = new CompleterFuture();
    }

    public function get future():Future {
        return _future;
    }

    public function isCompleted():Boolean {
        return _future.completed;
    }

    public function complete(value:*):void {
        _future.complete(value);
    }

    public function completeError(error:*):void {
        _future.completeError(error);
    }

    public function setProgress(ratio:Number):void {
        _future.setProgress(ratio);
    }

    public function reset():void {
        _future.reset();
    }

    public function wrap(f:Future):Completer {
        var self:CompleterFuture = this._future;
        f.then(self.complete, self.completeError);
        f.onProgress(self.setProgress)
        return this;
    }
}
}
