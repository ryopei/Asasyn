package com.github.asasyn {
import flash.events.HTTPStatusEvent;
import flash.net.URLLoader;
import flash.net.URLRequestHeader;

public class HttpResult {

    public function HttpResult(urlLoader:URLLoader, event:HTTPStatusEvent) {
        _urlLoader = urlLoader;

        if (event != null) {
            this._responseHeaders = event.responseHeaders;
            this._responseURL = event.responseURL;
            this._status = event.status;
            parseHeaders();
        }

    }

    private var _urlLoader:URLLoader;

    /**
     * URLRequestHeader Array
     */
    private var _responseHeaders:Array;
    private var _responseURL:String;
    private var _status:int;
    private var _contentType:String;


    public function get contentType():String {
        return _contentType;
    }

    public function get urlLoader():URLLoader {
        return _urlLoader;
    }

    public function get responseHeaders():Array {
        return _responseHeaders;
    }

    public function get responseURL():String {
        return _responseURL;
    }

    public function get status():int {
        return _status;
    }

    private function parseHeaders():void {
        for each(var h:URLRequestHeader in responseHeaders) {
            var name:String = h.name;
            if (name.toLocaleLowerCase() == "content-type") {
                _contentType = h.value;
            }

        }
    }
}
}
