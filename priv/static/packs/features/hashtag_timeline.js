(window.webpackJsonp=window.webpackJsonp||[]).push([[34],{121:function(t,e){var n=Array.isArray;t.exports=n},156:function(t,e,n){var r=n(479),o=n(482);t.exports=function(t,e){var n=o(t,e);return r(n)?n:void 0}},275:function(t,e,n){var r=n(495),o=n(496),a=n(497),i=n(498),s=n(499);function c(t){var e=-1,n=null==t?0:t.length;for(this.clear();++e<n;){var r=t[e];this.set(r[0],r[1])}}c.prototype.clear=r,c.prototype.delete=o,c.prototype.get=a,c.prototype.has=i,c.prototype.set=s,t.exports=c},276:function(t,e,n){var r=n(414);t.exports=function(t,e){for(var n=t.length;n--;)if(r(t[n][0],e))return n;return-1}},277:function(t,e,n){var r=n(156)(Object,"create");t.exports=r},278:function(t,e,n){var r=n(513);t.exports=function(t,e){var n=t.__data__;return r(e)?n["string"==typeof e?"string":"hash"]:n.map}},326:function(t,e,n){var r=n(156)(n(80),"Map");t.exports=r},328:function(t,e){var n=9007199254740991;t.exports=function(t){return"number"==typeof t&&t>-1&&t%1==0&&t<=n}},329:function(t,e,n){var r=n(505),o=n(512),a=n(514),i=n(515),s=n(516);function c(t){var e=-1,n=null==t?0:t.length;for(this.clear();++e<n;){var r=t[e];this.set(r[0],r[1])}}c.prototype.clear=r,c.prototype.delete=o,c.prototype.get=a,c.prototype.has=i,c.prototype.set=s,t.exports=c},381:function(t,e,n){var r=n(483),o=n(490),a=n(494);t.exports=function(t){return a(t)?r(t):o(t)}},410:function(t,e,n){var r=n(157),o=n(100),a="[object AsyncFunction]",i="[object Function]",s="[object GeneratorFunction]",c="[object Proxy]";t.exports=function(t){if(!o(t))return!1;var e=r(t);return e==i||e==s||e==a||e==c}},411:function(t,e){var n=Function.prototype.toString;t.exports=function(t){if(null!=t){try{return n.call(t)}catch(t){}try{return t+""}catch(t){}}return""}},412:function(t,e,n){(function(t){var r=n(80),o=n(486),a=e&&!e.nodeType&&e,i=a&&"object"==typeof t&&t&&!t.nodeType&&t,s=i&&i.exports===a?r.Buffer:void 0,c=(s?s.isBuffer:void 0)||o;t.exports=c}).call(this,n(237)(t))},413:function(t,e,n){var r=n(487),o=n(488),a=n(489),i=a&&a.isTypedArray,s=i?o(i):r;t.exports=s},414:function(t,e){t.exports=function(t,e){return t===e||t!=t&&e!=e}},415:function(t,e,n){var r=n(518),o=n(521),a=n(522),i=1,s=2;t.exports=function(t,e,n,c,u,p){var f=n&i,l=t.length,h=e.length;if(l!=h&&!(f&&h>l))return!1;var d=p.get(t);if(d&&p.get(e))return d==e;var b=-1,v=!0,g=n&s?new r:void 0;for(p.set(t,e),p.set(e,t);++b<l;){var _=t[b],j=e[b];if(c)var y=f?c(j,_,b,e,t,p):c(_,j,b,t,e,p);if(void 0!==y){if(y)continue;v=!1;break}if(g){if(!o(e,(function(t,e){if(!a(g,e)&&(_===t||u(_,t,n,c,p)))return g.push(e)}))){v=!1;break}}else if(_!==j&&!u(_,j,n,c,p)){v=!1;break}}return p.delete(t),p.delete(e),v}},416:function(t,e,n){var r=n(485),o=n(158),a=Object.prototype,i=a.hasOwnProperty,s=a.propertyIsEnumerable,c=r(function(){return arguments}())?r:function(t){return o(t)&&i.call(t,"callee")&&!s.call(t,"callee")};t.exports=c},417:function(t,e){var n=9007199254740991,r=/^(?:0|[1-9]\d*)$/;t.exports=function(t,e){var o=typeof t;return!!(e=null==e?n:e)&&("number"==o||"symbol"!=o&&r.test(t))&&t>-1&&t%1==0&&t<e}},418:function(t,e,n){var r=n(275),o=n(500),a=n(501),i=n(502),s=n(503),c=n(504);function u(t){var e=this.__data__=new r(t);this.size=e.size}u.prototype.clear=o,u.prototype.delete=a,u.prototype.get=i,u.prototype.has=s,u.prototype.set=c,t.exports=u},419:function(t,e,n){var r=n(517),o=n(158);t.exports=function t(e,n,a,i,s){return e===n||(null==e||null==n||!o(e)&&!o(n)?e!=e&&n!=n:r(e,n,a,i,t,s))}},479:function(t,e,n){var r=n(410),o=n(480),a=n(100),i=n(411),s=/^\[object .+?Constructor\]$/,c=Function.prototype,u=Object.prototype,p=c.toString,f=u.hasOwnProperty,l=RegExp("^"+p.call(f).replace(/[\\^$.*+?()[\]{}|]/g,"\\$&").replace(/hasOwnProperty|(function).*?(?=\\\()| for .+?(?=\\\])/g,"$1.*?")+"$");t.exports=function(t){return!(!a(t)||o(t))&&(r(t)?l:s).test(i(t))}},480:function(t,e,n){var r,o=n(481),a=(r=/[^.]+$/.exec(o&&o.keys&&o.keys.IE_PROTO||""))?"Symbol(src)_1."+r:"";t.exports=function(t){return!!a&&a in t}},481:function(t,e,n){var r=n(80)["__core-js_shared__"];t.exports=r},482:function(t,e){t.exports=function(t,e){return null==t?void 0:t[e]}},483:function(t,e,n){var r=n(484),o=n(416),a=n(121),i=n(412),s=n(417),c=n(413),u=Object.prototype.hasOwnProperty;t.exports=function(t,e){var n=a(t),p=!n&&o(t),f=!n&&!p&&i(t),l=!n&&!p&&!f&&c(t),h=n||p||f||l,d=h?r(t.length,String):[],b=d.length;for(var v in t)!e&&!u.call(t,v)||h&&("length"==v||f&&("offset"==v||"parent"==v)||l&&("buffer"==v||"byteLength"==v||"byteOffset"==v)||s(v,b))||d.push(v);return d}},484:function(t,e){t.exports=function(t,e){for(var n=-1,r=Array(t);++n<t;)r[n]=e(n);return r}},485:function(t,e,n){var r=n(157),o=n(158),a="[object Arguments]";t.exports=function(t){return o(t)&&r(t)==a}},486:function(t,e){t.exports=function(){return!1}},487:function(t,e,n){var r=n(157),o=n(328),a=n(158),i={};i["[object Float32Array]"]=i["[object Float64Array]"]=i["[object Int8Array]"]=i["[object Int16Array]"]=i["[object Int32Array]"]=i["[object Uint8Array]"]=i["[object Uint8ClampedArray]"]=i["[object Uint16Array]"]=i["[object Uint32Array]"]=!0,i["[object Arguments]"]=i["[object Array]"]=i["[object ArrayBuffer]"]=i["[object Boolean]"]=i["[object DataView]"]=i["[object Date]"]=i["[object Error]"]=i["[object Function]"]=i["[object Map]"]=i["[object Number]"]=i["[object Object]"]=i["[object RegExp]"]=i["[object Set]"]=i["[object String]"]=i["[object WeakMap]"]=!1,t.exports=function(t){return a(t)&&o(t.length)&&!!i[r(t)]}},488:function(t,e){t.exports=function(t){return function(e){return t(e)}}},489:function(t,e,n){(function(t){var r=n(279),o=e&&!e.nodeType&&e,a=o&&"object"==typeof t&&t&&!t.nodeType&&t,i=a&&a.exports===o&&r.process,s=function(){try{var t=a&&a.require&&a.require("util").types;return t||i&&i.binding&&i.binding("util")}catch(t){}}();t.exports=s}).call(this,n(237)(t))},490:function(t,e,n){var r=n(491),o=n(492),a=Object.prototype.hasOwnProperty;t.exports=function(t){if(!r(t))return o(t);var e=[];for(var n in Object(t))a.call(t,n)&&"constructor"!=n&&e.push(n);return e}},491:function(t,e){var n=Object.prototype;t.exports=function(t){var e=t&&t.constructor;return t===("function"==typeof e&&e.prototype||n)}},492:function(t,e,n){var r=n(493)(Object.keys,Object);t.exports=r},493:function(t,e){t.exports=function(t,e){return function(n){return t(e(n))}}},494:function(t,e,n){var r=n(410),o=n(328);t.exports=function(t){return null!=t&&o(t.length)&&!r(t)}},495:function(t,e){t.exports=function(){this.__data__=[],this.size=0}},496:function(t,e,n){var r=n(276),o=Array.prototype.splice;t.exports=function(t){var e=this.__data__,n=r(e,t);return!(n<0)&&(n==e.length-1?e.pop():o.call(e,n,1),--this.size,!0)}},497:function(t,e,n){var r=n(276);t.exports=function(t){var e=this.__data__,n=r(e,t);return n<0?void 0:e[n][1]}},498:function(t,e,n){var r=n(276);t.exports=function(t){return r(this.__data__,t)>-1}},499:function(t,e,n){var r=n(276);t.exports=function(t,e){var n=this.__data__,o=r(n,t);return o<0?(++this.size,n.push([t,e])):n[o][1]=e,this}},500:function(t,e,n){var r=n(275);t.exports=function(){this.__data__=new r,this.size=0}},501:function(t,e){t.exports=function(t){var e=this.__data__,n=e.delete(t);return this.size=e.size,n}},502:function(t,e){t.exports=function(t){return this.__data__.get(t)}},503:function(t,e){t.exports=function(t){return this.__data__.has(t)}},504:function(t,e,n){var r=n(275),o=n(326),a=n(329),i=200;t.exports=function(t,e){var n=this.__data__;if(n instanceof r){var s=n.__data__;if(!o||s.length<i-1)return s.push([t,e]),this.size=++n.size,this;n=this.__data__=new a(s)}return n.set(t,e),this.size=n.size,this}},505:function(t,e,n){var r=n(506),o=n(275),a=n(326);t.exports=function(){this.size=0,this.__data__={hash:new r,map:new(a||o),string:new r}}},506:function(t,e,n){var r=n(507),o=n(508),a=n(509),i=n(510),s=n(511);function c(t){var e=-1,n=null==t?0:t.length;for(this.clear();++e<n;){var r=t[e];this.set(r[0],r[1])}}c.prototype.clear=r,c.prototype.delete=o,c.prototype.get=a,c.prototype.has=i,c.prototype.set=s,t.exports=c},507:function(t,e,n){var r=n(277);t.exports=function(){this.__data__=r?r(null):{},this.size=0}},508:function(t,e){t.exports=function(t){var e=this.has(t)&&delete this.__data__[t];return this.size-=e?1:0,e}},509:function(t,e,n){var r=n(277),o="__lodash_hash_undefined__",a=Object.prototype.hasOwnProperty;t.exports=function(t){var e=this.__data__;if(r){var n=e[t];return n===o?void 0:n}return a.call(e,t)?e[t]:void 0}},510:function(t,e,n){var r=n(277),o=Object.prototype.hasOwnProperty;t.exports=function(t){var e=this.__data__;return r?void 0!==e[t]:o.call(e,t)}},511:function(t,e,n){var r=n(277),o="__lodash_hash_undefined__";t.exports=function(t,e){var n=this.__data__;return this.size+=this.has(t)?0:1,n[t]=r&&void 0===e?o:e,this}},512:function(t,e,n){var r=n(278);t.exports=function(t){var e=r(this,t).delete(t);return this.size-=e?1:0,e}},513:function(t,e){t.exports=function(t){var e=typeof t;return"string"==e||"number"==e||"symbol"==e||"boolean"==e?"__proto__"!==t:null===t}},514:function(t,e,n){var r=n(278);t.exports=function(t){return r(this,t).get(t)}},515:function(t,e,n){var r=n(278);t.exports=function(t){return r(this,t).has(t)}},516:function(t,e,n){var r=n(278);t.exports=function(t,e){var n=r(this,t),o=n.size;return n.set(t,e),this.size+=n.size==o?0:1,this}},517:function(t,e,n){var r=n(418),o=n(415),a=n(523),i=n(527),s=n(534),c=n(121),u=n(412),p=n(413),f=1,l="[object Arguments]",h="[object Array]",d="[object Object]",b=Object.prototype.hasOwnProperty;t.exports=function(t,e,n,v,g,_){var j=c(t),y=c(e),m=j?h:s(t),O=y?h:s(e),x=(m=m==l?d:m)==d,w=(O=O==l?d:O)==d,M=m==O;if(M&&u(t)){if(!u(e))return!1;j=!0,x=!1}if(M&&!x)return _||(_=new r),j||p(t)?o(t,e,n,v,g,_):a(t,e,m,n,v,g,_);if(!(n&f)){var A=x&&b.call(t,"__wrapped__"),S=w&&b.call(e,"__wrapped__");if(A||S){var z=A?t.value():t,P=S?e.value():e;return _||(_=new r),g(z,P,n,v,_)}}return!!M&&(_||(_=new r),i(t,e,n,v,g,_))}},518:function(t,e,n){var r=n(329),o=n(519),a=n(520);function i(t){var e=-1,n=null==t?0:t.length;for(this.__data__=new r;++e<n;)this.add(t[e])}i.prototype.add=i.prototype.push=o,i.prototype.has=a,t.exports=i},519:function(t,e){var n="__lodash_hash_undefined__";t.exports=function(t){return this.__data__.set(t,n),this}},520:function(t,e){t.exports=function(t){return this.__data__.has(t)}},521:function(t,e){t.exports=function(t,e){for(var n=-1,r=null==t?0:t.length;++n<r;)if(e(t[n],n,t))return!0;return!1}},522:function(t,e){t.exports=function(t,e){return t.has(e)}},523:function(t,e,n){var r=n(160),o=n(524),a=n(414),i=n(415),s=n(525),c=n(526),u=1,p=2,f="[object Boolean]",l="[object Date]",h="[object Error]",d="[object Map]",b="[object Number]",v="[object RegExp]",g="[object Set]",_="[object String]",j="[object Symbol]",y="[object ArrayBuffer]",m="[object DataView]",O=r?r.prototype:void 0,x=O?O.valueOf:void 0;t.exports=function(t,e,n,r,O,w,M){switch(n){case m:if(t.byteLength!=e.byteLength||t.byteOffset!=e.byteOffset)return!1;t=t.buffer,e=e.buffer;case y:return!(t.byteLength!=e.byteLength||!w(new o(t),new o(e)));case f:case l:case b:return a(+t,+e);case h:return t.name==e.name&&t.message==e.message;case v:case _:return t==e+"";case d:var A=s;case g:var S=r&u;if(A||(A=c),t.size!=e.size&&!S)return!1;var z=M.get(t);if(z)return z==e;r|=p,M.set(t,e);var P=i(A(t),A(e),r,O,w,M);return M.delete(t),P;case j:if(x)return x.call(t)==x.call(e)}return!1}},524:function(t,e,n){var r=n(80).Uint8Array;t.exports=r},525:function(t,e){t.exports=function(t){var e=-1,n=Array(t.size);return t.forEach((function(t,r){n[++e]=[r,t]})),n}},526:function(t,e){t.exports=function(t){var e=-1,n=Array(t.size);return t.forEach((function(t){n[++e]=t})),n}},527:function(t,e,n){var r=n(528),o=1,a=Object.prototype.hasOwnProperty;t.exports=function(t,e,n,i,s,c){var u=n&o,p=r(t),f=p.length;if(f!=r(e).length&&!u)return!1;for(var l=f;l--;){var h=p[l];if(!(u?h in e:a.call(e,h)))return!1}var d=c.get(t);if(d&&c.get(e))return d==e;var b=!0;c.set(t,e),c.set(e,t);for(var v=u;++l<f;){var g=t[h=p[l]],_=e[h];if(i)var j=u?i(_,g,h,e,t,c):i(g,_,h,t,e,c);if(!(void 0===j?g===_||s(g,_,n,i,c):j)){b=!1;break}v||(v="constructor"==h)}if(b&&!v){var y=t.constructor,m=e.constructor;y!=m&&"constructor"in t&&"constructor"in e&&!("function"==typeof y&&y instanceof y&&"function"==typeof m&&m instanceof m)&&(b=!1)}return c.delete(t),c.delete(e),b}},528:function(t,e,n){var r=n(529),o=n(531),a=n(381);t.exports=function(t){return r(t,a,o)}},529:function(t,e,n){var r=n(530),o=n(121);t.exports=function(t,e,n){var a=e(t);return o(t)?a:r(a,n(t))}},530:function(t,e){t.exports=function(t,e){for(var n=-1,r=e.length,o=t.length;++n<r;)t[o+n]=e[n];return t}},531:function(t,e,n){var r=n(532),o=n(533),a=Object.prototype.propertyIsEnumerable,i=Object.getOwnPropertySymbols,s=i?function(t){return null==t?[]:(t=Object(t),r(i(t),(function(e){return a.call(t,e)})))}:o;t.exports=s},532:function(t,e){t.exports=function(t,e){for(var n=-1,r=null==t?0:t.length,o=0,a=[];++n<r;){var i=t[n];e(i,n,t)&&(a[o++]=i)}return a}},533:function(t,e){t.exports=function(){return[]}},534:function(t,e,n){var r=n(535),o=n(326),a=n(536),i=n(537),s=n(538),c=n(157),u=n(411),p=u(r),f=u(o),l=u(a),h=u(i),d=u(s),b=c;(r&&"[object DataView]"!=b(new r(new ArrayBuffer(1)))||o&&"[object Map]"!=b(new o)||a&&"[object Promise]"!=b(a.resolve())||i&&"[object Set]"!=b(new i)||s&&"[object WeakMap]"!=b(new s))&&(b=function(t){var e=c(t),n="[object Object]"==e?t.constructor:void 0,r=n?u(n):"";if(r)switch(r){case p:return"[object DataView]";case f:return"[object Map]";case l:return"[object Promise]";case h:return"[object Set]";case d:return"[object WeakMap]"}return e}),t.exports=b},535:function(t,e,n){var r=n(156)(n(80),"DataView");t.exports=r},536:function(t,e,n){var r=n(156)(n(80),"Promise");t.exports=r},537:function(t,e,n){var r=n(156)(n(80),"Set");t.exports=r},538:function(t,e,n){var r=n(156)(n(80),"WeakMap");t.exports=r},850:function(t,e,n){"use strict";n.r(e),n.d(e,"default",(function(){return z}));var r,o=n(0),a=n(2),i=(n(9),n(6),n(8)),s=n(1),c=n(1148),u=n.n(c),p=n(3),f=n.n(p),l=n(15),h=n(1063),d=n(762),b=n(759),v=n(7),g=n(307),_=n.n(g),j=n(1176);var y,m=Object(v.f)({placeholder:{id:"hashtag.column_settings.select.placeholder",defaultMessage:"Enter hashtags…"},noOptions:{id:"hashtag.column_settings.select.no_options_message",defaultMessage:"No suggestions found"}}),O=Object(v.g)(r=function(t){Object(i.a)(n,t);var e;e=n;function n(){for(var e,n=arguments.length,r=new Array(n),o=0;o<n;o++)r[o]=arguments[o];return e=t.call.apply(t,[this].concat(r))||this,Object(s.a)(Object(a.a)(e),"state",{open:e.hasTags()}),Object(s.a)(Object(a.a)(e),"onSelect",(function(t){return function(n){return e.props.onChange(["tags",t],n)}})),Object(s.a)(Object(a.a)(e),"onToggle",(function(){e.state.open&&e.hasTags()&&e.props.onChange("tags",{}),e.setState({open:!e.state.open})})),Object(s.a)(Object(a.a)(e),"noOptionsMessage",(function(){return e.props.intl.formatMessage(m.noOptions)})),e}var r=n.prototype;return r.hasTags=function(){var t=this;return["all","any","none"].map((function(e){return t.tags(e).length>0})).includes(!0)},r.tags=function(t){var e=this.props.settings.getIn(["tags",t])||[];return e.toJSON?e.toJSON():e},r.modeSelect=function(t){return Object(o.a)("div",{className:"column-settings__row"},void 0,Object(o.a)("span",{className:"column-settings__section"},void 0,this.modeLabel(t)),Object(o.a)(j.a,{isMulti:!0,autoFocus:!0,value:this.tags(t),onChange:this.onSelect(t),loadOptions:this.props.onLoad,className:"column-select__container",classNamePrefix:"column-select",name:"tags",placeholder:this.props.intl.formatMessage(m.placeholder),noOptionsMessage:this.noOptionsMessage}))},r.modeLabel=function(t){switch(t){case"any":return Object(o.a)(v.b,{id:"hashtag.column_settings.tag_mode.any",defaultMessage:"Any of these"});case"all":return Object(o.a)(v.b,{id:"hashtag.column_settings.tag_mode.all",defaultMessage:"All of these"});case"none":return Object(o.a)(v.b,{id:"hashtag.column_settings.tag_mode.none",defaultMessage:"None of these"});default:return""}},r.render=function(){return Object(o.a)("div",{},void 0,Object(o.a)("div",{className:"column-settings__row"},void 0,Object(o.a)("div",{className:"setting-toggle"},void 0,Object(o.a)(_.a,{id:"hashtag.column_settings.tag_toggle",onChange:this.onToggle,checked:this.state.open}),Object(o.a)("span",{className:"setting-toggle__label"},void 0,Object(o.a)(v.b,{id:"hashtag.column_settings.tag_toggle",defaultMessage:"Include additional tags in this column"})))),this.state.open&&Object(o.a)("div",{className:"column-settings__hashtags"},void 0,this.modeSelect("any"),this.modeSelect("all"),this.modeSelect("none")))},n}(f.a.PureComponent))||r,x=n(253),w=n(12),M=Object(l.connect)((function(t,e){var n=e.columnId,r=t.getIn(["settings","columns"]),o=r.findIndex((function(t){return t.get("uuid")===n}));return n&&o>=0?{settings:r.get(o).get("params")}:{}}),(function(t,e){var n=e.columnId;return{onChange:function(e,r){t(Object(x.f)(n,e,r))},onLoad:function(t){return Object(w.a)().get("/api/v2/search",{params:{q:t,type:"hashtags"}}).then((function(t){return(t.data.hashtags||[]).map((function(t){return{value:t.name,label:"#"+t.name}}))}))}}}))(O),A=n(36),S=n(766);var z=Object(l.connect)((function(t,e){return{hasUnread:t.getIn(["timelines","hashtag:"+e.params.id,"unread"])>0}}))(y=function(t){Object(i.a)(n,t);var e;e=n;function n(){for(var e,n=arguments.length,r=new Array(n),i=0;i<n;i++)r[i]=arguments[i];return e=t.call.apply(t,[this].concat(r))||this,Object(s.a)(Object(a.a)(e),"disconnects",[]),Object(s.a)(Object(a.a)(e),"handlePin",(function(){var t=e.props,n=t.columnId,r=t.dispatch;r(n?Object(x.h)(n):Object(x.e)("HASHTAG",{id:e.props.params.id}))})),Object(s.a)(Object(a.a)(e),"title",(function(){var t=[e.props.params.id];return e.additionalFor("any")&&t.push(" ",Object(o.a)(v.b,{id:"hashtag.column_header.tag_mode.any",values:{additional:e.additionalFor("any")},defaultMessage:"or {additional}"},"any")),e.additionalFor("all")&&t.push(" ",Object(o.a)(v.b,{id:"hashtag.column_header.tag_mode.all",values:{additional:e.additionalFor("all")},defaultMessage:"and {additional}"},"all")),e.additionalFor("none")&&t.push(" ",Object(o.a)(v.b,{id:"hashtag.column_header.tag_mode.none",values:{additional:e.additionalFor("none")},defaultMessage:"without {additional}"},"none")),t})),Object(s.a)(Object(a.a)(e),"additionalFor",(function(t){var n=e.props.params.tags;return n&&(n[t]||[]).length>0?n[t].map((function(t){return t.value})).join("/"):""})),Object(s.a)(Object(a.a)(e),"handleMove",(function(t){var n=e.props,r=n.columnId;(0,n.dispatch)(Object(x.g)(r,t))})),Object(s.a)(Object(a.a)(e),"handleHeaderClick",(function(){e.column.scrollTop()})),Object(s.a)(Object(a.a)(e),"setRef",(function(t){e.column=t})),Object(s.a)(Object(a.a)(e),"handleLoadMore",(function(t){var n=e.props.params,r=n.id,o=n.tags;e.props.dispatch(Object(A.s)(r,{maxId:t,tags:o}))})),e}var r=n.prototype;return r._subscribe=function(t,e,n){var r=this;void 0===n&&(n={});var o=(n.any||[]).map((function(t){return t.value})),a=(n.all||[]).map((function(t){return t.value})),i=(n.none||[]).map((function(t){return t.value}));[e].concat(o).map((function(n){r.disconnects.push(t(Object(S.c)(e,n,(function(t){var e=t.tags.map((function(t){return t.name}));return a.filter((function(t){return e.includes(t)})).length===a.length&&0===i.filter((function(t){return e.includes(t)})).length}))))}))},r._unsubscribe=function(){this.disconnects.map((function(t){return t()})),this.disconnects=[]},r.componentDidMount=function(){var t=this.props.dispatch,e=this.props.params,n=e.id,r=e.tags;this._subscribe(t,n,r),t(Object(A.s)(n,{tags:r}))},r.componentWillReceiveProps=function(t){var e=this.props,n=e.dispatch,r=e.params,o=t.params,a=o.id,i=o.tags;a===r.id&&u()(i,r.tags)||(this._unsubscribe(),this._subscribe(n,a,i),this.props.dispatch(Object(A.k)("hashtag:"+a)),this.props.dispatch(Object(A.s)(a,{tags:i})))},r.componentWillUnmount=function(){this._unsubscribe()},r.render=function(){var t=this.props,e=t.shouldUpdateScroll,n=t.hasUnread,r=t.columnId,a=t.multiColumn,i=this.props.params.id,s=!!r;return f.a.createElement(d.a,{bindToDocument:!a,ref:this.setRef,label:"#"+i},Object(o.a)(b.a,{icon:"hashtag",active:n,title:this.title(),onPin:this.handlePin,onMove:this.handleMove,onClick:this.handleHeaderClick,pinned:s,multiColumn:a,showBackButton:!0},void 0,r&&Object(o.a)(M,{columnId:r})),Object(o.a)(h.a,{trackScroll:!s,scrollKey:"hashtag_timeline-"+r,timelineId:"hashtag:"+i,onLoadMore:this.handleLoadMore,emptyMessage:Object(o.a)(v.b,{id:"empty_column.hashtag",defaultMessage:"There is nothing in this hashtag yet."}),shouldUpdateScroll:e,bindToDocument:!a}))},n}(f.a.PureComponent))||y}}]);
//# sourceMappingURL=hashtag_timeline.js.map