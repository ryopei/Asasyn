package com.github.asasyn {
/**
 * 非同期処理のコールバックを登録するためのインターフェース
 */
public interface Future {

    /**
     * @param onComplete (value:*->void)
     * @param onError (error:Error->void)
     * @return
     */
    function then(onComplete:Function, onError:Function = null):Future;

    /**
     * @param timeout seconds
     * @param onTimeout (error:Error->void)
     * @return
     */
    function setTimeout(timeout:Number, onTimeout:Function = null):Future;


    /**
     * @param onProgress (ratio:Number->void) ration 0..1.0
     * @return
     */
    function onProgress(onProgress:Function):Future;

    /**
     * 現在の進行度を返す。
     * [0.0 ,1.0]
     */
    function get progress():Number;

    /**
     * @param next:* Futureを返すファンクション
     * @return
     */
    function chain(next:Function, ...params):Future;

    /**
     *
     * @return
     */
    function later():Future;
}
}
