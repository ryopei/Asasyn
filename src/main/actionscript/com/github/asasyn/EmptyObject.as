/**
 * Created with IntelliJ IDEA.
 * User: katsume
 * Date: 2013/08/06
 * Time: 18:40
 * To change this template use File | Settings | File Templates.
 */
package com.github.asasyn {

class EmptyObject {
    public function EmptyObject() {
    }

    public static const instance:EmptyObject = new EmptyObject();

    public static function get():EmptyObject {
        return instance;
    }
}
}
