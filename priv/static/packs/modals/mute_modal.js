(window.webpackJsonp=window.webpackJsonp||[]).push([[242],{829:function(t,e,o){"use strict";o.r(e),o.d(e,"default",(function(){return j}));var n,a=o(0),i=o(2),c=(o(9),o(6),o(8)),s=o(1),l=o(3),u=o.n(l),d=o(15),r=o(7),m=o(307),f=o.n(m),b=o(110),p=o(48),g=o(26),h=o(212);var j=Object(d.connect)((function(t){return{account:t.getIn(["mutes","new","account"]),notifications:t.getIn(["mutes","new","notifications"])}}),(function(t){return{onConfirm:function(e,o){t(Object(g.G)(e.get("id"),o))},onClose:function(){t(Object(p.c)())},onToggleNotifications:function(){t(Object(h.h)())}}}))(n=Object(r.g)(n=function(t){Object(c.a)(o,t);var e;e=o;function o(){for(var e,o=arguments.length,n=new Array(o),a=0;a<o;a++)n[a]=arguments[a];return e=t.call.apply(t,[this].concat(n))||this,Object(s.a)(Object(i.a)(e),"handleClick",(function(){e.props.onClose(),e.props.onConfirm(e.props.account,e.props.notifications)})),Object(s.a)(Object(i.a)(e),"handleCancel",(function(){e.props.onClose()})),Object(s.a)(Object(i.a)(e),"setRef",(function(t){e.button=t})),Object(s.a)(Object(i.a)(e),"toggleNotifications",(function(){e.props.onToggleNotifications()})),e}var n=o.prototype;return n.componentDidMount=function(){this.button.focus()},n.render=function(){var t=this.props,e=t.account,o=t.notifications;return(Object(a.a)("div",{className:"modal-root__modal mute-modal"},void 0,Object(a.a)("div",{className:"mute-modal__container"},void 0,Object(a.a)("p",{},void 0,Object(a.a)(r.b,{id:"confirmations.mute.message",defaultMessage:"Are you sure you want to mute {name}?",values:{name:Object(a.a)("strong",{},void 0,"@",e.get("acct"))}})),Object(a.a)("p",{className:"mute-modal__explanation"},void 0,Object(a.a)(r.b,{id:"confirmations.mute.explanation",defaultMessage:"This will hide posts from them and posts mentioning them, but it will still allow them to see your posts and follow you."})),Object(a.a)("div",{className:"setting-toggle"},void 0,Object(a.a)(f.a,{id:"mute-modal__hide-notifications-checkbox",checked:o,onChange:this.toggleNotifications}),Object(a.a)("label",{className:"setting-toggle__label",htmlFor:"mute-modal__hide-notifications-checkbox"},void 0,Object(a.a)(r.b,{id:"mute_modal.hide_notifications",defaultMessage:"Hide notifications from this user?"})))),Object(a.a)("div",{className:"mute-modal__action-bar"},void 0,Object(a.a)(b.a,{onClick:this.handleCancel,className:"mute-modal__cancel-button"},void 0,Object(a.a)(r.b,{id:"confirmation_modal.cancel",defaultMessage:"Cancel"})),u.a.createElement(b.a,{onClick:this.handleClick,ref:this.setRef},Object(a.a)(r.b,{id:"confirmations.mute.confirm",defaultMessage:"Mute"})))))},o}(u.a.PureComponent))||n)||n}}]);
//# sourceMappingURL=mute_modal.js.map