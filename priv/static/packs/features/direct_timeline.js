(window.webpackJsonp=window.webpackJsonp||[]).push([[17],{702:function(e,t,n){"use strict";n.r(t);var i=n(1),c=n(6),r=n(0),s=n(2),o=n(3),u=n.n(o),a=n(20),d=n(430),l=n(428),p=n(98),h=n(203),b=n(7),j=n(399),O=n(32),f=n(40),v=n(53),M=n.n(v),g=n(5),m=n.n(g),y=n(26),I=n.n(y),w=n(24),k=n(631),C=function(o){function e(){for(var a,e=arguments.length,t=new Array(e),n=0;n<e;n++)t[n]=arguments[n];return a=o.call.apply(o,[this].concat(t))||this,Object(s.a)(Object(r.a)(Object(r.a)(a)),"handleClick",function(){if(a.context.router){var e=a.props,t=e.lastStatusId,n=e.unread,o=e.markRead;n&&o(),a.context.router.history.push("/statuses/"+t)}}),Object(s.a)(Object(r.a)(Object(r.a)(a)),"handleHotkeyMoveUp",function(){a.props.onMoveUp(a.props.conversationId)}),Object(s.a)(Object(r.a)(Object(r.a)(a)),"handleHotkeyMoveDown",function(){a.props.onMoveDown(a.props.conversationId)}),a}return Object(c.a)(e,o),e.prototype.render=function(){var e=this.props,t=e.accounts,n=e.lastStatusId,o=e.unread;return null===n?null:Object(i.a)(k.a,{id:n,unread:o,otherAccounts:t,onMoveUp:this.handleHotkeyMoveUp,onMoveDown:this.handleHotkeyMoveDown,onClick:this.handleClick})},e}(w.a);Object(s.a)(C,"contextTypes",{router:m.a.object}),Object(s.a)(C,"propTypes",{conversationId:m.a.string.isRequired,accounts:I.a.list.isRequired,lastStatusId:m.a.string,unread:m.a.bool.isRequired,onMoveUp:m.a.func,onMoveDown:m.a.func,markRead:m.a.func.isRequired});var L=Object(a.connect)(function(t,e){var n=e.conversationId,o=t.getIn(["conversations","items"]).find(function(e){return e.get("id")===n});return{accounts:o.get("accounts").map(function(e){return t.getIn(["accounts",e],null)}),unread:o.get("unread"),lastStatusId:o.get("last_status",null)}},function(e,t){var n=t.conversationId;return{markRead:function(){return e(Object(p.i)(n))}}})(C),R=n(641),U=function(a){function e(){for(var n,e=arguments.length,t=new Array(e),o=0;o<e;o++)t[o]=arguments[o];return n=a.call.apply(a,[this].concat(t))||this,Object(s.a)(Object(r.a)(Object(r.a)(n)),"getCurrentIndex",function(t){return n.props.conversations.findIndex(function(e){return e.get("id")===t})}),Object(s.a)(Object(r.a)(Object(r.a)(n)),"handleMoveUp",function(e){var t=n.getCurrentIndex(e)-1;n._selectChild(t)}),Object(s.a)(Object(r.a)(Object(r.a)(n)),"handleMoveDown",function(e){var t=n.getCurrentIndex(e)+1;n._selectChild(t)}),Object(s.a)(Object(r.a)(Object(r.a)(n)),"setRef",function(e){n.node=e}),Object(s.a)(Object(r.a)(Object(r.a)(n)),"handleLoadOlder",M()(function(){var e=n.props.conversations.last();e&&e.get("last_status")&&n.props.onLoadMore(e.get("last_status"))},300,{leading:!0})),n}Object(c.a)(e,a);var t=e.prototype;return t._selectChild=function(e){var t=this.node.node.querySelector("article:nth-of-type("+(e+1)+") .focusable");t&&t.focus()},t.render=function(){var t=this,e=this.props,n=e.conversations,o=e.onLoadMore,a=Object(f.a)(e,["conversations","onLoadMore"]);return u.a.createElement(R.a,Object(O.a)({},a,{onLoadMore:o&&this.handleLoadOlder,scrollKey:"direct",ref:this.setRef}),n.map(function(e){return Object(i.a)(L,{conversationId:e.get("id"),onMoveUp:t.handleMoveUp,onMoveDown:t.handleMoveDown},e.get("id"))}))},e}(w.a);Object(s.a)(U,"propTypes",{conversations:I.a.list.isRequired,hasMore:m.a.bool,isLoading:m.a.bool,onLoadMore:m.a.func,shouldUpdateScroll:m.a.func});var D,x=Object(a.connect)(function(e){return{conversations:e.getIn(["conversations","items"]),isLoading:e.getIn(["conversations","isLoading"],!0),hasMore:e.getIn(["conversations","hasMore"],!1)}},function(t){return{onLoadMore:function(e){return t(Object(p.h)({maxId:e}))}}})(U);n.d(t,"default",function(){return _});var S=Object(b.f)({title:{id:"column.direct",defaultMessage:"Direct messages"}}),_=Object(a.connect)()(D=Object(b.g)(D=function(a){function e(){for(var o,e=arguments.length,t=new Array(e),n=0;n<e;n++)t[n]=arguments[n];return o=a.call.apply(a,[this].concat(t))||this,Object(s.a)(Object(r.a)(Object(r.a)(o)),"handlePin",function(){var e=o.props,t=e.columnId,n=e.dispatch;n(t?Object(h.h)(t):Object(h.e)("DIRECT",{}))}),Object(s.a)(Object(r.a)(Object(r.a)(o)),"handleMove",function(e){var t=o.props,n=t.columnId;(0,t.dispatch)(Object(h.g)(n,e))}),Object(s.a)(Object(r.a)(Object(r.a)(o)),"handleHeaderClick",function(){o.column.scrollTop()}),Object(s.a)(Object(r.a)(Object(r.a)(o)),"setRef",function(e){o.column=e}),Object(s.a)(Object(r.a)(Object(r.a)(o)),"handleLoadMore",function(e){o.props.dispatch(Object(p.h)({maxId:e}))}),o}Object(c.a)(e,a);var t=e.prototype;return t.componentDidMount=function(){var e=this.props.dispatch;e(Object(p.j)()),e(Object(p.h)()),this.disconnect=e(Object(j.b)())},t.componentWillUnmount=function(){this.props.dispatch(Object(p.k)()),this.disconnect&&(this.disconnect(),this.disconnect=null)},t.render=function(){var e=this.props,t=e.intl,n=e.hasUnread,o=e.columnId,a=e.multiColumn,c=e.shouldUpdateScroll,r=!!o;return u.a.createElement(d.a,{ref:this.setRef,label:t.formatMessage(S.title)},Object(i.a)(l.a,{icon:"envelope",active:n,title:t.formatMessage(S.title),onPin:this.handlePin,onMove:this.handleMove,onClick:this.handleHeaderClick,pinned:r,multiColumn:a}),Object(i.a)(x,{trackScroll:!r,scrollKey:"direct_timeline-"+o,timelineId:"direct",onLoadMore:this.handleLoadMore,emptyMessage:Object(i.a)(b.b,{id:"empty_column.direct",defaultMessage:"You don't have any direct messages yet. When you send or receive one, it will show up here."}),shouldUpdateScroll:c}))},e}(u.a.PureComponent))||D)||D}}]);
//# sourceMappingURL=direct_timeline.js.map