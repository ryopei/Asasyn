package net.asasyn {
public class ParallelResult {
    public function ParallelResult(error:Boolean, data:Object) {
        _isError = error;
        _data = data;
    }

    private var _isError:Boolean;

    private var _data:Object;

    public function get isError():Boolean {
        return _isError;
    }

    public function get data():Object {
        return _data;
    }
}
}
