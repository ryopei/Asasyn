package net.asasyn {

import flash.display.Loader;
import flash.events.Event;
import flash.events.HTTPStatusEvent;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.TimerEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.net.URLLoader;
import flash.net.URLLoaderDataFormat;
import flash.net.URLRequest;
import flash.system.LoaderContext;
import flash.utils.ByteArray;
import flash.utils.Timer;

public class Futures {

    public static var DEBUG_MODE:Boolean = false;

    /**
     *
     * @return
     */
    public static function later():Future {
        return delayed(0);
    }

    /**
     *
     * @param delay seconds
     * @return void
     */
    public static function delayed(delay:Number):Future {

        var completer:Completer = new Completer();

        var timer:Timer = new Timer(delay * 1000, 1);
        var func:Function = function (e:TimerEvent):void {
            timer.removeEventListener(TimerEvent.TIMER_COMPLETE, func);
            completer.complete(null);
        };
        timer.addEventListener(TimerEvent.TIMER_COMPLETE, func);
        timer.start();
        return completer.future;

    }

    /**
     * 読み込み用にファイルをオープンします。
     *
     * @param file
     * @return FileStream
     */
    public static function openFile(file:File):Future {
        var completer:Completer = new Completer();

        var fs:FileStream = new FileStream();
        var onComplete:Function = function (e:Event):void {
            fs.removeEventListener(Event.COMPLETE, onComplete);
            fs.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
            completer.complete(fs);

        }
        var onIoError:Function = function (e:IOErrorEvent):void {
            fs.removeEventListener(Event.COMPLETE, onComplete);
            fs.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
            completer.completeError(e);
        }
        fs.addEventListener(Event.COMPLETE, onComplete);
        fs.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
        fs.openAsync(file, FileMode.READ);

        return completer.future;
    }

    /**
     * ファイルに書き込みを行います。
     *
     * @param file
     * @param writer Function<FileSteam>:void
     * @return Void
     */
    public static function writeFile(file:File, writer:Function):Future {
        var completer:Completer = new Completer();
        var fs:FileStream = new FileStream();
        var onIoError:Function = function (e:IOErrorEvent):void {
            fs.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
            fs.removeEventListener(Event.CLOSE, onClose);
            completer.completeError(e);
        }

        var onClose:Function = function (e:Event):void {
            fs.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
            fs.removeEventListener(Event.CLOSE, onClose);
            completer.complete(null);
        }

        try {
            fs.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
            fs.addEventListener(Event.CLOSE, onClose);
            fs.openAsync(file, FileMode.UPDATE);
            writer(fs);
            fs.close();
        } catch (e:Error) {
            completer.completeError(e);
        }

        return completer.future;
    }

    private static var parallelId:int = 0;

    /**
     * 複数の非同期処理を実行して、全て成功した場合、結果をArrayで返す。
     * いずれかの処理でエラーが発生した場合、エラーを返す。
     * @param futures
     * @return net.asasyn.Future<Array> 結果配列を返します。
     */
    public static function parallel(...futures):Future {

        var pid:int = parallelId++;
        if (DEBUG_MODE) {
            trace("start parallel id:" + pid + ", futures:" + futures);
        }


        if (futures.length == 1 && futures[0] is Array) {
            return parallel.apply(null, futures[0]);
        }

        var completer:Completer = new Completer();
        var results:Array = new Array(futures.length);
        var errors:Vector.<ParallelResult> = new Vector.<ParallelResult>(futures.length);
        var errorHappened:Boolean = false;
        var completeNum:int = 0;

        var progress:Vector.<Number> = new Vector.<Number>(futures.length);
        for (var i:int = 0; i < futures.length; i++) {
            progress[i] = 0;
            var f:Future = futures[i];
            if (f == null) {
                progress[i] = 1
                results[i] = null;
                continue;
            }
            (function (index:int, future:Future):void {
                future.then(function (v:*):void {

                    if (DEBUG_MODE) {
                        trace("complete parallel id:" + pid + "func:" + index);
                    }

                    results[index] = v;
                    errors[index] = new ParallelResult(false, v);
                    if (++completeNum == futures.length) {
                        if (errorHappened) {
                            completer.completeError(errors);
                        }
                        else {
                            completer.complete(results);
                        }
                    }

                }, function (e:*):void {
                    if (DEBUG_MODE) {
                        trace("error parallel id:" + pid + "func:" + index);
                    }
                    errorHappened = true;
                    errors[index] = new ParallelResult(true, e);
                    if (++completeNum == futures.length) {
                        completer.completeError(errors);
                    }
                }).onProgress(
                        function (ratio:Number):void {
                            progress[index] = ratio;
                            var sum:Number = 0;
                            for each(var r:Number in progress) {
                                sum += r;
                            }
                            completer.setProgress(sum / futures.length);
                        }
                );
            })(i, f);
        }
        return completer.future;
    }

    /**
     * 複数の非同期処理を同時に実行し、最初に処理が終了した非同期処理の結果を返します。<br/>
     * エラーについては全ての処理がエラーとなった場合に、全エラーのArrayを返します。<br/>
     * 投機的実行をする場合にも有効です。
     * @param futures
     * @return
     */
    public static function first(...futures):Future {
        if (futures.length == 1 && futures[0] is Array) {
            return first.apply(null, futures[0]);
        }
        var completer:Completer = new Completer();
        var errors:Array = [];

        for each (var future:Future in futures) {
            future.then(function (v:*):void {
                if (!completer.isCompleted()) {
                    completer.complete(v);
                }
            }, function (e:*):void {
                errors.push(e);
                if (errors.length == futures.length) {
                    completer.completeError(errors);
                }
            });
        }
        return completer.future;
    }

//    public static function loop(f:Function, num:int):Future {
//        var futures:Array = new Array();
//        for (var i:int = 0; i < num; i++) {
//            futures.push(f(i));
//        }
//        return parallel(futures);
//    }

    /**
     * @param url
     * @return Future[loader:URLLoader, error:*]
     */
    public static function loadUrl(url:String, responseDataFormat:String = URLLoaderDataFormat.TEXT):Future {
        var req:URLRequest = new URLRequest(url);
        return urlRequest(req, responseDataFormat);
    }


    /**
     * ByteArrayを読み込む
     * @param url
     * @return
     */
    public static function loadByteArray(url:String):Future {
        var completer:Completer = new Completer();

        loadUrl(url, URLLoaderDataFormat.BINARY).then(function (loader:URLLoader):void {
            completer.complete(loader.data);
        }, completer.completeError);

        return completer.future;
    }

    /**
     * Loaderを使用してURLからBitmap/MovieClipを読み込む。
     * @param url URL
     * @return Loader#content(Bitmap, MovieClip, etc...)
     */
    public static function loaderLoad(url:String):Future {
        var completer:Completer = new Completer();
        loadByteArray(url).then(function (ba:ByteArray):void {
            loaderLoadBytes(ba).then(completer.complete, completer.completeError);
        }, completer.completeError);
        return completer.future;
    }

    /**
     * Loaderを使用してByteArrayからBitmap/MovieClipを読み込む。
     * @param bytes Byte配列
     * @return Loader#content(Bitmap, MovieClip, etc...)
     */
    public static function loaderLoadBytes(bytes:ByteArray):Future {
        try {
            var context:LoaderContext = new LoaderContext();
            context.allowCodeImport = true;

            var completer:Completer = new Completer();
            var loader:Loader = new Loader();
            var onComplete:Function = function (e:Event):void {
                loader.removeEventListener(Event.COMPLETE, onComplete);
                completer.complete(loader.content);
                loader.unload();
            };
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onComplete);
            loader.loadBytes(bytes, context);
            return completer.future;
        }
        catch (error:Error) {
            return Futures.error(error);
        }
        return null;
    }

    /**
     * 成功時にURLLoaderオブジェクトを返します。<br/>
     * HTTPのステータスコードやヘッダ等、より詳細なレスポンスが必要な場合は、urlRequest2を使用します。
     * @param req
     * @param responseDataFormat
     * @return URLLoader, エラーEvent
     */
    public static function urlRequest(req:URLRequest, responseDataFormat:String = URLLoaderDataFormat.TEXT):Future {
        var completer:Completer = new Completer();
        urlRequest2(req, responseDataFormat).then(function (r:HttpResult):void {
            completer.complete(r.urlLoader);
        }, completer.completeError);
        return completer.future;
    }


    /**
     * 成功時にHttpResultオブジェクトを返します。
     * @param req
     * @param responseDataFormat
     * @return
     */
    public static function urlRequest2(req:URLRequest, responseDataFormat:String = URLLoaderDataFormat.TEXT):Future {
        var completer:Completer = new Completer();
        var loader:URLLoader = new URLLoader();
        var httpStatusEvent:HTTPStatusEvent = null;
        loader.dataFormat = responseDataFormat;
        var onIOError:Function = function (e:IOErrorEvent):void {
            removeListeners();
            completer.completeError(e);
        }

        var onComplete:Function = function (e:Event):void {
            removeListeners();
            completer.complete(new HttpResult(loader, httpStatusEvent));
        }

        var onProgress:Function = function (e:ProgressEvent):void {
            if (0 < loader.bytesTotal) {
                completer.setProgress(loader.bytesLoaded / loader.bytesTotal);
            }
        }

        var onHttpStatus:Function = function (e:HTTPStatusEvent):void {
            httpStatusEvent = e;
        }

        var removeListeners:Function = function ():void {
            loader.removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
            loader.removeEventListener(Event.COMPLETE, onComplete);
            loader.removeEventListener(ProgressEvent.PROGRESS, onProgress);
            loader.removeEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onHttpStatus);
        }

        loader.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
        loader.addEventListener(Event.COMPLETE, onComplete);
        loader.addEventListener(ProgressEvent.PROGRESS, onProgress);
        loader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onHttpStatus);
        loader.load(req);
        return completer.future;
    }


    /**
     * URLを指定してJSONを読み込む
     * @param url
     * @return Future[Object] json object
     */
    public static function loadJson(url:String):Future {
        var completer:Completer = new Completer();
        var str:String = null;
        loadUrl(url).then(function (loader:URLLoader):void {
            try {
                var str:String = loader.data;
                completer.complete(JSON.parse(str));
            }
            catch (e:Error) {
                trace("Json Parse Error", url, str);
                completer.completeError(e);
            }
        }, completer.completeError).onProgress(completer.setProgress);
        return completer.future;
    }

    /**
     * URLを指定してXMLを読み込む
     * @param url
     * @return Future[XML] json object
     */
    public static function loadXml(url:String):Future {
        var completer:Completer = new Completer();
        loadUrl(url).then(function (loader:URLLoader):void {
            try {
                completer.complete(new XML(loader.data));
            }
            catch (e:Error) {
                completer.completeError(e);
            }
        }, completer.completeError).onProgress(completer.setProgress);
        return completer.future;
    }


    public function Futures() {
    }

    /**
     * 成功オブジェクトを返します。
     * @param obj
     * @return
     */
    public static function success(obj:*):Future {
        var completer:Completer = new Completer();
        later().then(function ():void {
            completer.complete(obj);
        });
        return completer.future;
    }

    /**
     * エラーオブジェクトを返します。
     * @param e
     * @return
     */
    public static function error(e:*):Future {
        var completer:Completer = new Completer();
        later().then(function ():void {
            completer.completeError(e);
        });
        return completer.future;
    }
}
}
