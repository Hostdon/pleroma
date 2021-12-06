(window.webpackJsonp=window.webpackJsonp||[]).push([["chunk-a104"],{"2IY7":function(t,e,s){"use strict";s.r(e);var r=s("o0o1"),a=s.n(r),o=s("yXPU"),n=s.n(o),i=s("dpNl"),c=s("rIUS"),l=s("yrTF"),p={name:"ReportsShow",components:{ModerateUserDropdown:i.a,RebootButton:c.a,ReportContent:l.a},computed:{isMobile:function(){return"mobile"===this.$store.state.app.device},loading:function(){return this.$store.state.reports.loadingSingleReport},report:function(){return this.$store.state.reports.singleReport}},mounted:function(){this.$store.dispatch("NeedReboot"),this.$store.dispatch("GetNodeInfo"),this.$store.dispatch("FetchSingleReport",this.$route.params.id),this.$store.dispatch("FetchTagPolicySetting")},methods:{capitalizeFirstLetter:function(t){return t.charAt(0).toUpperCase()+t.slice(1)},changeReportState:function(t,e){var s=this;return n()(a.a.mark(function r(){return a.a.wrap(function(r){for(;;)switch(r.prev=r.next){case 0:return r.next=2,s.$store.dispatch("ChangeReportState",[{state:t,id:e}]);case 2:s.$store.dispatch("FetchSingleReport",e);case 3:case"end":return r.stop()}},r)}))()},getStateType:function(t){switch(t){case"closed":return"info";case"resolved":return"success";default:return"primary"}},propertyExists:function(t,e,s){return s?t[e]&&t[s]:t[e]}}},u=(s("pE88"),s("KHd+")),d=Object(u.a)(p,function(){var t=this,e=t.$createElement,s=t._self._c||e;return t.loading?t._e():s("div",{staticClass:"report-show-page-container"},[s("header",{staticClass:"report-page-header-container"},[s("div",{staticClass:"report-page-header"},[t.propertyExists(t.report.account,"nickname")?s("div",{staticClass:"avatar-name-container"},[s("h1",[t._v(t._s(t.$t("reports.reportOn")))]),t._v(" "),t.propertyExists(t.report.account,"avatar")?s("el-avatar",{staticClass:"report-page-avatar",attrs:{src:t.report.account.avatar,size:t.isMobile?"small":"large"}}):t._e(),t._v(" "),s("h1",[t._v(t._s(t.report.account.nickname))]),t._v(" "),t.propertyExists(t.report.account,"url")?s("a",{attrs:{href:t.report.account.url,target:"_blank"}},[s("i",{staticClass:"el-icon-top-right",attrs:{title:t.$t("userProfile.openAccountInInstance")}})]):t._e()],1):s("h1",[t._v(t._s(t.$t("reports.report")))])]),t._v(" "),s("div",{staticClass:"report-actions-container"},[s("el-tag",{staticClass:"report-tag",attrs:{type:t.getStateType(t.report.state)}},[t._v(t._s(t.capitalizeFirstLetter(t.report.state)))]),t._v(" "),s("el-dropdown",{attrs:{trigger:"click"}},[s("el-button",{staticClass:"report-actions-button",attrs:{size:t.isMobile?"small":"medium",plain:"",icon:"el-icon-edit"}},[t._v("\n          "+t._s(t.$t("reports.changeState"))),s("i",{staticClass:"el-icon-arrow-down el-icon--right"})]),t._v(" "),s("el-dropdown-menu",{attrs:{slot:"dropdown"},slot:"dropdown"},["resolved"!==t.report.state?s("el-dropdown-item",{nativeOn:{click:function(e){return t.changeReportState("resolved",t.report.id)}}},[t._v(t._s(t.$t("reports.resolve")))]):t._e(),t._v(" "),"open"!==t.report.state?s("el-dropdown-item",{nativeOn:{click:function(e){return t.changeReportState("open",t.report.id)}}},[t._v(t._s(t.$t("reports.reopen")))]):t._e(),t._v(" "),"closed"!==t.report.state?s("el-dropdown-item",{nativeOn:{click:function(e){return t.changeReportState("closed",t.report.id)}}},[t._v(t._s(t.$t("reports.close")))]):t._e()],1)],1),t._v(" "),t.propertyExists(t.report.account,"nickname")?s("moderate-user-dropdown",{attrs:{account:t.report.account,"report-id":t.report.id,"rendered-from":"showPage"}}):t._e(),t._v(" "),s("reboot-button")],1)]),t._v(" "),t.propertyExists(t.report.account,"id")?s("h4",{staticClass:"id"},[t._v(t._s(t.$t("reports.id"))+": "+t._s(t.report.id))]):t._e(),t._v(" "),s("div",{staticClass:"report-card-container"},[s("el-card",{staticClass:"report"},[s("report-content",{attrs:{report:t.report}})],1)],1)])},[],!1,null,null,null);d.options.__file="show.vue";e.default=d.exports},"9Dgh":function(t,e,s){"use strict";var r=s("R1GW");s.n(r).a},"G/Mk":function(t,e,s){"use strict";var r=s("xdcp");s.n(r).a},R1GW:function(t,e,s){},RnhZ:function(t,e,s){var r={"./af":"K/tc","./af.js":"K/tc","./ar":"jnO4","./ar-dz":"o1bE","./ar-dz.js":"o1bE","./ar-kw":"Qj4J","./ar-kw.js":"Qj4J","./ar-ly":"HP3h","./ar-ly.js":"HP3h","./ar-ma":"CoRJ","./ar-ma.js":"CoRJ","./ar-sa":"gjCT","./ar-sa.js":"gjCT","./ar-tn":"bYM6","./ar-tn.js":"bYM6","./ar.js":"jnO4","./az":"SFxW","./az.js":"SFxW","./be":"H8ED","./be.js":"H8ED","./bg":"hKrs","./bg.js":"hKrs","./bm":"p/rL","./bm.js":"p/rL","./bn":"kEOa","./bn.js":"kEOa","./bo":"0mo+","./bo.js":"0mo+","./br":"aIdf","./br.js":"aIdf","./bs":"JVSJ","./bs.js":"JVSJ","./ca":"1xZ4","./ca.js":"1xZ4","./cs":"PA2r","./cs.js":"PA2r","./cv":"A+xa","./cv.js":"A+xa","./cy":"l5ep","./cy.js":"l5ep","./da":"DxQv","./da.js":"DxQv","./de":"tGlX","./de-at":"s+uk","./de-at.js":"s+uk","./de-ch":"u3GI","./de-ch.js":"u3GI","./de.js":"tGlX","./dv":"WYrj","./dv.js":"WYrj","./el":"jUeY","./el.js":"jUeY","./en-au":"Dmvi","./en-au.js":"Dmvi","./en-ca":"OIYi","./en-ca.js":"OIYi","./en-gb":"Oaa7","./en-gb.js":"Oaa7","./en-ie":"4dOw","./en-ie.js":"4dOw","./en-il":"czMo","./en-il.js":"czMo","./en-in":"7C5Q","./en-in.js":"7C5Q","./en-nz":"b1Dy","./en-nz.js":"b1Dy","./en-sg":"t+mt","./en-sg.js":"t+mt","./eo":"Zduo","./eo.js":"Zduo","./es":"iYuL","./es-do":"CjzT","./es-do.js":"CjzT","./es-us":"Vclq","./es-us.js":"Vclq","./es.js":"iYuL","./et":"7BjC","./et.js":"7BjC","./eu":"D/JM","./eu.js":"D/JM","./fa":"jfSC","./fa.js":"jfSC","./fi":"gekB","./fi.js":"gekB","./fil":"1ppg","./fil.js":"1ppg","./fo":"ByF4","./fo.js":"ByF4","./fr":"nyYc","./fr-ca":"2fjn","./fr-ca.js":"2fjn","./fr-ch":"Dkky","./fr-ch.js":"Dkky","./fr.js":"nyYc","./fy":"cRix","./fy.js":"cRix","./ga":"USCx","./ga.js":"USCx","./gd":"9rRi","./gd.js":"9rRi","./gl":"iEDd","./gl.js":"iEDd","./gom-deva":"qvJo","./gom-deva.js":"qvJo","./gom-latn":"DKr+","./gom-latn.js":"DKr+","./gu":"4MV3","./gu.js":"4MV3","./he":"x6pH","./he.js":"x6pH","./hi":"3E1r","./hi.js":"3E1r","./hr":"S6ln","./hr.js":"S6ln","./hu":"WxRl","./hu.js":"WxRl","./hy-am":"1rYy","./hy-am.js":"1rYy","./id":"UDhR","./id.js":"UDhR","./is":"BVg3","./is.js":"BVg3","./it":"bpih","./it-ch":"bxKX","./it-ch.js":"bxKX","./it.js":"bpih","./ja":"B55N","./ja.js":"B55N","./jv":"tUCv","./jv.js":"tUCv","./ka":"IBtZ","./ka.js":"IBtZ","./kk":"bXm7","./kk.js":"bXm7","./km":"6B0Y","./km.js":"6B0Y","./kn":"PpIw","./kn.js":"PpIw","./ko":"Ivi+","./ko.js":"Ivi+","./ku":"JCF/","./ku.js":"JCF/","./ky":"lgnt","./ky.js":"lgnt","./lb":"RAwQ","./lb.js":"RAwQ","./lo":"sp3z","./lo.js":"sp3z","./lt":"JvlW","./lt.js":"JvlW","./lv":"uXwI","./lv.js":"uXwI","./me":"KTz0","./me.js":"KTz0","./mi":"aIsn","./mi.js":"aIsn","./mk":"aQkU","./mk.js":"aQkU","./ml":"AvvY","./ml.js":"AvvY","./mn":"lYtQ","./mn.js":"lYtQ","./mr":"Ob0Z","./mr.js":"Ob0Z","./ms":"6+QB","./ms-my":"ZAMP","./ms-my.js":"ZAMP","./ms.js":"6+QB","./mt":"G0Uy","./mt.js":"G0Uy","./my":"honF","./my.js":"honF","./nb":"bOMt","./nb.js":"bOMt","./ne":"OjkT","./ne.js":"OjkT","./nl":"+s0g","./nl-be":"2ykv","./nl-be.js":"2ykv","./nl.js":"+s0g","./nn":"uEye","./nn.js":"uEye","./oc-lnc":"Fnuy","./oc-lnc.js":"Fnuy","./pa-in":"8/+R","./pa-in.js":"8/+R","./pl":"jVdC","./pl.js":"jVdC","./pt":"8mBD","./pt-br":"0tRk","./pt-br.js":"0tRk","./pt.js":"8mBD","./ro":"lyxo","./ro.js":"lyxo","./ru":"lXzo","./ru.js":"lXzo","./sd":"Z4QM","./sd.js":"Z4QM","./se":"//9w","./se.js":"//9w","./si":"7aV9","./si.js":"7aV9","./sk":"e+ae","./sk.js":"e+ae","./sl":"gVVK","./sl.js":"gVVK","./sq":"yPMs","./sq.js":"yPMs","./sr":"zx6S","./sr-cyrl":"E+lV","./sr-cyrl.js":"E+lV","./sr.js":"zx6S","./ss":"Ur1D","./ss.js":"Ur1D","./sv":"X709","./sv.js":"X709","./sw":"dNwA","./sw.js":"dNwA","./ta":"PeUW","./ta.js":"PeUW","./te":"XLvN","./te.js":"XLvN","./tet":"V2x9","./tet.js":"V2x9","./tg":"Oxv6","./tg.js":"Oxv6","./th":"EOgW","./th.js":"EOgW","./tk":"Wv91","./tk.js":"Wv91","./tl-ph":"Dzi0","./tl-ph.js":"Dzi0","./tlh":"z3Vd","./tlh.js":"z3Vd","./tr":"DoHr","./tr.js":"DoHr","./tzl":"z1FC","./tzl.js":"z1FC","./tzm":"wQk9","./tzm-latn":"tT3J","./tzm-latn.js":"tT3J","./tzm.js":"wQk9","./ug-cn":"YRex","./ug-cn.js":"YRex","./uk":"raLr","./uk.js":"raLr","./ur":"UpQW","./ur.js":"UpQW","./uz":"Loxo","./uz-latn":"AQ68","./uz-latn.js":"AQ68","./uz.js":"Loxo","./vi":"KSF8","./vi.js":"KSF8","./x-pseudo":"/X5v","./x-pseudo.js":"/X5v","./yo":"fzPg","./yo.js":"fzPg","./zh-cn":"XDpg","./zh-cn.js":"XDpg","./zh-hk":"SatO","./zh-hk.js":"SatO","./zh-mo":"OmwH","./zh-mo.js":"OmwH","./zh-tw":"kOpN","./zh-tw.js":"kOpN"};function a(t){var e=o(t);return s(e)}function o(t){if(!s.o(r,t)){var e=new Error("Cannot find module '"+t+"'");throw e.code="MODULE_NOT_FOUND",e}return r[t]}a.keys=function(){return Object.keys(r)},a.resolve=o,t.exports=a,a.id="RnhZ"},"W2/d":function(t,e,s){},dpNl:function(t,e,s){"use strict";var r={name:"ModerateUserDropdown",props:{account:{type:Object,required:!0},reportId:{type:String,required:!0},renderedFrom:{type:String,required:!0}},computed:{isMobile:function(){return"mobile"===this.$store.state.app.device},tagPolicyEnabled:function(){return this.$store.state.users.mrfPolicies.includes("Pleroma.Web.ActivityPub.MRF.TagPolicy")},tags:function(){return this.account.tags||[]}},methods:{enableTagPolicy:function(){var t=this;this.$confirm(this.$t("users.confirmEnablingTagPolicy"),{confirmButtonText:"Yes",cancelButtonText:"Cancel",type:"warning"}).then(function(){t.$message({type:"success",message:t.$t("users.enableTagPolicySuccessMessage")}),t.$store.dispatch("EnableTagPolicy")}).catch(function(){t.$message({type:"info",message:"Canceled"})})},handleDeactivation:function(t){"showPage"===this.renderedFrom?t.is_active?this.$store.dispatch("DeactivateUserFromReportShow",t):this.$store.dispatch("ActivateUserFromReportShow",t):"reportsPage"===this.renderedFrom&&(t.is_active?this.$store.dispatch("DeactivateUserFromReports",{user:t,reportId:this.reportId}):this.$store.dispatch("ActivateUserFromReports",{user:t,reportId:this.reportId}))},handleDeletion:function(t){var e=this;this.$confirm(this.$t("users.deleteUserConfirmation"),{confirmButtonText:"Delete",cancelButtonText:"Cancel",type:"warning"}).then(function(){e.$store.dispatch("DeleteUserFromReports",{user:t,reportId:e.reportId})}).catch(function(){e.$message({type:"info",message:"Delete canceled"})})},showDeactivatedButton:function(t){return this.$store.state.user.id!==t},toggleTag:function(t,e){"showPage"===this.renderedFrom?t.tags.includes(e)?this.$store.dispatch("RemoveTagFromReportsFromReportShow",{user:t,tag:e}):this.$store.dispatch("AddTagFromReportsFromReportShow",{user:t,tag:e}):"reportsPage"===this.renderedFrom&&(t.tags.includes(e)?this.$store.dispatch("RemoveTagFromReports",{user:t,tag:e,reportId:this.reportId}):this.$store.dispatch("AddTagFromReports",{user:t,tag:e,reportId:this.reportId}))}}},a=(s("9Dgh"),s("KHd+")),o=Object(a.a)(r,function(){var t=this,e=t.$createElement,s=t._self._c||e;return s("el-dropdown",{attrs:{"hide-on-click":!1,trigger:"click"}},[s("el-button",{attrs:{disabled:!t.account.id,size:"showPage"!==t.renderedFrom||t.isMobile?"small":"medium",plain:"",icon:"el-icon-files"}},[t._v("\n    "+t._s(t.$t("reports.moderateUser"))+"\n    "),s("i",{staticClass:"el-icon-arrow-down el-icon--right"})]),t._v(" "),s("el-dropdown-menu",{staticClass:"moderate-user-dropdown",attrs:{slot:"dropdown"},slot:"dropdown"},[t.showDeactivatedButton(t.account)?s("el-dropdown-item",{nativeOn:{click:function(e){return t.handleDeactivation(t.account)}}},[t._v("\n      "+t._s(t.account.is_active?t.$t("users.deactivateAccount"):t.$t("users.activateAccount"))+"\n    ")]):t._e(),t._v(" "),t.showDeactivatedButton(t.account.id)?s("el-dropdown-item",{nativeOn:{click:function(e){return t.handleDeletion(t.account)}}},[t._v("\n      "+t._s(t.$t("users.deleteAccount"))+"\n    ")]):t._e(),t._v(" "),t.tagPolicyEnabled?s("el-dropdown-item",{class:{"active-tag":t.tags.includes("mrf_tag:media-force-nsfw")},attrs:{divided:!0},nativeOn:{click:function(e){return t.toggleTag(t.account,"mrf_tag:media-force-nsfw")}}},[t._v("\n      "+t._s(t.$t("users.forceNsfw"))+"\n      "),t.tags.includes("mrf_tag:media-force-nsfw")?s("i",{staticClass:"el-icon-check"}):t._e()]):t._e(),t._v(" "),t.tagPolicyEnabled?s("el-dropdown-item",{class:{"active-tag":t.tags.includes("mrf_tag:media-strip")},nativeOn:{click:function(e){return t.toggleTag(t.account,"mrf_tag:media-strip")}}},[t._v("\n      "+t._s(t.$t("users.stripMedia"))+"\n      "),t.tags.includes("mrf_tag:media-strip")?s("i",{staticClass:"el-icon-check"}):t._e()]):t._e(),t._v(" "),t.tagPolicyEnabled?s("el-dropdown-item",{class:{"active-tag":t.tags.includes("mrf_tag:force-unlisted")},nativeOn:{click:function(e){return t.toggleTag(t.account,"mrf_tag:force-unlisted")}}},[t._v("\n      "+t._s(t.$t("users.forceUnlisted"))+"\n      "),t.tags.includes("mrf_tag:force-unlisted")?s("i",{staticClass:"el-icon-check"}):t._e()]):t._e(),t._v(" "),t.tagPolicyEnabled?s("el-dropdown-item",{class:{"active-tag":t.tags.includes("mrf_tag:sandbox")},nativeOn:{click:function(e){return t.toggleTag(t.account,"mrf_tag:sandbox")}}},[t._v("\n      "+t._s(t.$t("users.sandbox"))+"\n      "),t.tags.includes("mrf_tag:sandbox")?s("i",{staticClass:"el-icon-check"}):t._e()]):t._e(),t._v(" "),t.tagPolicyEnabled&&t.account.local?s("el-dropdown-item",{class:{"active-tag":t.tags.includes("mrf_tag:disable-remote-subscription")},nativeOn:{click:function(e){return t.toggleTag(t.account,"mrf_tag:disable-remote-subscription")}}},[t._v("\n      "+t._s(t.$t("users.disableRemoteSubscription"))+"\n      "),t.tags.includes("mrf_tag:disable-remote-subscription")?s("i",{staticClass:"el-icon-check"}):t._e()]):t._e(),t._v(" "),t.tagPolicyEnabled&&t.account.local?s("el-dropdown-item",{class:{"active-tag":t.tags.includes("mrf_tag:disable-any-subscription")},nativeOn:{click:function(e){return t.toggleTag(t.account,"mrf_tag:disable-any-subscription")}}},[t._v("\n      "+t._s(t.$t("users.disableAnySubscription"))+"\n      "),t.tags.includes("mrf_tag:disable-any-subscription")?s("i",{staticClass:"el-icon-check"}):t._e()]):t._e(),t._v(" "),t.tagPolicyEnabled?t._e():s("el-dropdown-item",{staticClass:"no-hover",attrs:{divided:""},nativeOn:{click:function(e){return t.enableTagPolicy(e)}}},[t._v("\n      "+t._s(t.$t("users.enableTagPolicy"))+"\n    ")])],1)],1)},[],!1,null,null,null);o.options.__file="ModerateUserDropdown.vue";e.a=o.exports},oDbL:function(t,e,s){"use strict";var r=s("W2/d");s.n(r).a},pE88:function(t,e,s){"use strict";var r=s("yZ2X");s.n(r).a},xdcp:function(t,e,s){},yZ2X:function(t,e,s){},yrTF:function(t,e,s){"use strict";var r=s("wd/R"),a=s.n(r),o={name:"NoteCard",props:{report:{type:Object,required:!0},note:{type:Object,required:!0}},methods:{handleNoteDeletion:function(t,e){var s=this;this.$confirm("Are you sure you want to delete this note?","Warning",{confirmButtonText:"OK",cancelButtonText:"Cancel",type:"warning"}).then(function(){s.$store.dispatch("DeleteReportNote",{noteID:t,reportID:e}),s.$message({type:"success",message:"Delete completed"})}).catch(function(){s.$message({type:"info",message:"Delete canceled"})})},parseTimestamp:function(t){return a()(t).format("YYYY-MM-DD HH:mm")},propertyExists:function(t,e){return t[e]}}},n=(s("G/Mk"),s("KHd+")),i=Object(n.a)(o,function(){var t=this,e=t.$createElement,s=t._self._c||e;return s("el-card",{staticClass:"note-card"},[s("div",{attrs:{slot:"header"},slot:"header"},[s("div",{staticClass:"note-header"},[t.propertyExists(t.note.user,"id")?s("router-link",{staticClass:"router-link",attrs:{to:{name:"UsersShow",params:{id:t.note.user.id}}}},[s("div",{staticClass:"note-actor"},[t.propertyExists(t.note.user,"avatar")?s("img",{staticClass:"note-avatar-img",attrs:{src:t.note.user.avatar,alt:"avatar"}}):t._e(),t._v(" "),t.propertyExists(t.note.user,"nickname")?s("span",{staticClass:"note-actor-name"},[t._v(t._s(t.note.user.nickname))]):s("span",{staticClass:"note-actor-name deactivated"},[t._v("("+t._s(t.$t("users.invalidNickname"))+")")])])]):t._e(),t._v(" "),s("el-button",{attrs:{size:"mini"},nativeOn:{click:function(e){return t.handleNoteDeletion(t.note.id,t.report.id)}}},[t._v("\n        "+t._s(t.$t("reports.deleteNote"))+"\n      ")])],1)]),t._v(" "),s("div",{staticClass:"note-body"},[s("span",{staticClass:"note-content",domProps:{innerHTML:t._s(t.note.content)}}),t._v("\n    "+t._s(t.parseTimestamp(t.note.created_at))+"\n  ")])])},[],!1,null,null,null);i.options.__file="NoteCard.vue";var c={name:"ReportContent",components:{NoteCard:i.exports,Status:s("ot3S").a},props:{report:{type:Object,required:!0}},data:function(){return{notes:{}}},computed:{currentPage:function(){return this.$store.state.reports.currentPage}},methods:{getNotesTitle:function(){var t=arguments.length>0&&void 0!==arguments[0]?arguments[0]:[];return"Notes: ".concat(t.length," item(s)")},getStatusesTitle:function(){var t=arguments.length>0&&void 0!==arguments[0]?arguments[0]:[];return"Reported statuses: ".concat(t.length," item(s)")},handleNewNote:function(t){this.$store.dispatch("CreateReportNote",{content:this.notes[t],reportID:t}),this.notes[t]=""},propertyExists:function(t,e,s){return s?t[e]&&t[s]:t[e]},showStatuses:function(){return(arguments.length>0&&void 0!==arguments[0]?arguments[0]:[]).length>0}}},l=(s("oDbL"),Object(n.a)(c,function(){var t=this,e=t.$createElement,s=t._self._c||e;return s("div",[s("div",{staticClass:"report-account-container"},[s("span",{staticClass:"report-row-key"},[t._v(t._s(t.$t("reports.account"))+":")]),t._v(" "),s("div",{staticClass:"report-account"},[t.propertyExists(t.report.account,"id")?s("router-link",{staticClass:"router-link",attrs:{to:{name:"UsersShow",params:{id:t.report.account.id}}}},[t.propertyExists(t.report.account,"avatar")?s("img",{staticClass:"avatar-img",attrs:{src:t.report.account.avatar,alt:"avatar"}}):t._e(),t._v(" "),t.propertyExists(t.report.account,"nickname")?s("span",{staticClass:"report-account-name"},[t._v(t._s(t.report.account.nickname))]):s("span",{staticClass:"report-account-name deactivated"},[t._v("("+t._s(t.$t("users.invalidNickname"))+")")])]):s("span",{staticClass:"report-account-name deactivated"},[t._v("("+t._s(t.$t("users.invalidNickname"))+")")]),t._v(" "),t.propertyExists(t.report.account,"url")?s("a",{staticClass:"account",attrs:{href:t.report.account.url,target:"_blank"}},[t._v("\n        "+t._s(t.$t("userProfile.openAccountInInstance"))+"\n        "),s("i",{staticClass:"el-icon-top-right"})]):t._e()],1)]),t._v(" "),t.report.content&&t.report.content.length>0?s("div",[s("el-divider",{staticClass:"divider"}),t._v(" "),s("span",{staticClass:"report-row-key"},[t._v(t._s(t.$t("reports.content"))+":\n      "),s("span",[t._v(t._s(t.report.content))])])],1):t._e(),t._v(" "),s("el-divider",{staticClass:"divider"}),t._v(" "),s("div",{staticClass:"report-account-container",style:t.showStatuses(t.report.statuses)?"":"margin-bottom:15px"},[s("span",{staticClass:"report-row-key"},[t._v(t._s(t.$t("reports.actor"))+":")]),t._v(" "),s("div",{staticClass:"report-account"},[t.propertyExists(t.report.actor,"id")?s("router-link",{staticClass:"router-link",attrs:{to:{name:"UsersShow",params:{id:t.report.actor.id}}}},[t.propertyExists(t.report.actor,"avatar")?s("img",{staticClass:"avatar-img",attrs:{src:t.report.actor.avatar,alt:"avatar"}}):t._e(),t._v(" "),t.propertyExists(t.report.actor,"nickname")?s("span",{staticClass:"report-account-name"},[t._v(t._s(t.report.actor.nickname))]):s("span",{staticClass:"report-account-name deactivated"},[t._v("("+t._s(t.$t("users.invalidNickname"))+")")])]):s("span",{staticClass:"report-account-name deactivated"},[t._v("("+t._s(t.$t("users.invalidNickname"))+")")]),t._v(" "),t.propertyExists(t.report.actor,"url")?s("a",{staticClass:"account",attrs:{href:t.report.actor.url,target:"_blank"}},[t._v("\n        "+t._s(t.$t("userProfile.openAccountInInstance"))+"\n        "),s("i",{staticClass:"el-icon-top-right"})]):t._e()],1)]),t._v(" "),t.showStatuses(t.report.statuses)?s("div",{staticClass:"reported-statuses"},[s("el-collapse",[s("el-collapse-item",{attrs:{title:t.getStatusesTitle(t.report.statuses)}},t._l(t.report.statuses,function(e){return s("div",{key:e.id},[s("status",{attrs:{status:e,account:e.account.nickname?e.account:t.report.account,"show-checkbox":!1,page:t.currentPage}})],1)}),0)],1)],1):t._e(),t._v(" "),s("div",[s("el-collapse",[s("el-collapse-item",{attrs:{title:t.getNotesTitle(t.report.notes)}},t._l(t.report.notes,function(e,r){return s("note-card",{key:r,attrs:{note:e,report:t.report}})}),1)],1),t._v(" "),s("div",{staticClass:"report-note-form"},[s("el-input",{attrs:{placeholder:t.$t("reports.leaveNote"),type:"textarea",rows:"2"},model:{value:t.notes[t.report.id],callback:function(e){t.$set(t.notes,t.report.id,e)},expression:"notes[report.id]"}}),t._v(" "),s("div",{staticClass:"report-post-note"},[s("el-button",{on:{click:function(e){return t.handleNewNote(t.report.id)}}},[t._v(t._s(t.$t("reports.postNote")))])],1)],1)],1)],1)},[],!1,null,null,null));l.options.__file="ReportContent.vue";e.a=l.exports}}]);
//# sourceMappingURL=chunk-a104.3439d73d.js.map