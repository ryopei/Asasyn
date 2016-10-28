package net.asasyn {
internal class CompleterFuture implements Future {

    public function CompleterFuture() {
    }

    private var sigComplete:Dispatcher = new Dispatcher();
    private var sigError:Dispatcher = new Dispatcher();
    private var sigProgress:Dispatcher = new Dispatcher();


    private var _timeouted:Boolean;

    private var _completed:Boolean;
    private var _value:* = EmptyObject.get();

    private var _progress:Number = 0;


    internal function reset():void {
        _completed = false;
        _value = EmptyObject.get();
        _progress = 0;
        _timeouted = false;
    }

    public function get completed():Boolean {
        return _completed;
    }

    public function get value():* {
        return _value;
    }

    private var _error:* = EmptyObject.get();

    public function get error():* {
        return _error;
    }

    public function then(onComplete:Function, onError:Function = null):Future {
        if (onComplete != null) {
            sigComplete.add(onComplete);
        }
        if (onError != null) {
            sigError.add(onError);
        }
        check();
        return this;
    }

    /**
     *
     * @param timeout タイムアウト時間(sec)
     * @param onTimeout Function<Error>
     * @return
     */
    public function setTimeout(timeout:Number, onTimeout:Function = null):Future {

        var error:Error = new Error();

        Futures.delayed(timeout).then(function (v:*):void {
            if (_timeouted || _completed) {
                return;
            }
            sigError.removeAll();
            sigComplete.removeAll();
            _timeouted = true;
            if (onTimeout != null) {
                var location:String = error.getStackTrace().match(/(?<=\/|\\)\w+?.as:\d+?(?=])/g)[1].replace(":", ", line ");
                onTimeout(new Error("timeout :" + location));
            }
        });


        return this;
    }

    public function get progress():Number {
        return _progress;
    }

    internal function setProgress(ratio:Number):void {
        _progress = ratio;
        sigProgress.dispatch(ratio);
        if (laterCompleter != null) {
            laterCompleter.setProgress(ratio);
        }
    }

    internal function complete(value:*):void {
        if (_timeouted || _completed) {
            return;
        }

        if (progress != 1.0) {
            setProgress(1.0);
        }

        _completed = true;
        _value = value;
        check();
    }


    internal function completeError(error:*):void {
        if (_timeouted || _completed) {
            return;
        }
        _completed = true;
        _error = error;
        check();
    }

    private function check():void {
        if (_value != EmptyObject.get()) {
            sigComplete.dispatch(_value);
            if (laterCompleter != null) {
                laterCompleter.complete(_value);
            }
            laterCompleter = null;
            sigComplete.removeAll();
            sigError.removeAll();
            sigProgress.removeAll();
            return;
        }

        if (_error != EmptyObject.get()) {
            sigError.dispatch(_error);
            if (laterCompleter != null) {
                laterCompleter.completeError(_error);
            }
            laterCompleter = null;
            sigComplete.removeAll();
            sigError.removeAll();
            sigProgress.removeAll();
        }
    }

    public function onProgress(onProgress:Function):Future {
        if (onProgress != null) {
            sigProgress.add(onProgress);
        }
        return this;
    }


    /**
     *
     * @param next 引き続き実行する関数
     * @param params 実行する関数に
     * @return
     */
    public function chain(next:Function, ...params):Future {

        var completer:Completer = new Completer();
        this.then(function (ret:*):void {
            for (var i:int = 0; i < params.length; i++) {
                var param:* = params[i];
                if (param is String) {
                    var str:String = param;
                    if (str == "$$") {
                        param = ret;
                    } else if (str.indexOf("@") == 0) {
                        var key:String = str.substring(1);
                        param = ret[key];
                    }
                    else if (str.indexOf("$") == 0) {
                        var key:String = str.substring(1);
                        param = ret[int(key)];
                    }
                }
                params[i] = param;
            }

            var nextResult:* = next.apply(null, params);
            if (nextResult is Future) {
                (nextResult as Future).then(completer.complete, completer.completeError)
                        .onProgress(completer.setProgress);
            }
            else {
                completer.complete(nextResult);
            }
        }, completer.completeError);

        return completer.future;
    }

    private var laterCompleter:Completer = null;

    public function later():Future {
        if (laterCompleter == null) {
            laterCompleter = new Completer();
        }
        return laterCompleter.future;
    }
}
}
