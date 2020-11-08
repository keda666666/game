<?php 
include_once "config.php";
$name=SafeSql($_SESSION['wanjiauser']);
$pwd=md5(SafeSql($_SESSION['wanjiapasswd']));
$url="http://sighttp.qq.com/msgrd?v=1&uin=".$gmqq;
if($_SESSION['wanjiauser']=='' || $_SESSION['wanjiapasswd']=='' ||  $gg - $_SESSION['ggwanjia']  > 6000 || $_SESSION['ggwanjia'] == ''){
echo '
		<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="1;url=login.php?order='.$order.'">
<title>登录提示</title>
<link rel="stylesheet" href="//cdn.bootcss.com/bootstrap/3.3.4/css/bootstrap.min.css">
<script src="//cdn.bootcss.com/jquery/1.11.2/jquery.min.js"></script>
<script src="//cdn.bootcss.com/bootstrap/3.3.4/js/bootstrap.min.js"></script>
</head>
<body>
	<div class="container" style="margin-top:9%;">
  		<div class="jumbotron">
		<p><h3>亲爱的玩家：</h3></p>
          <p><li>很抱歉，您尚未登录！如未能跳转，请<a href="login.php?order='.$order.'">点击此处</a></li></p>
        <!--  <p><li>如需了解详情，请<a href="'.$url.'">联系GM</a>处理。</li></p> -->
        </div>
	</div>
	
	
	
</body>
</html>
';	
exit;	
}
?>
<!DOCTYPE HTML>
<html>

<head>
	<meta charset="utf-8">
	<title>ICE西游</title>
	<!--防止index.html被浏览器缓存--begin-->
	<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
	<META HTTP-EQUIV="Cache-Control" CONTENT="no-cache">
	<META HTTP-EQUIV="Expires" CONTENT="0">
	<!--防止index.html被浏览器缓存--over-->
	
	<!-- <link rel="stylesheet" type="text/css" href="layui/css/datouwang.css"> -->
	
	<meta name="viewport" content="width=device-width,initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="full-screen" content="true" />
	<meta name="screen-orientation" content="portrait" />
	<meta name="x5-fullscreen" content="true" />
	<meta name="360-fullscreen" content="true" />
	<style>
        html, body {
            -ms-touch-action: none;
            background: #000000;
            padding: 0;
            border: 0;
            margin: 0;
            height: 100%;
			overflow: hidden;
        }
    </style>
	
	
	<script egret="lib" src="libs/modules/egret/egret.min.js" src-release="libs/modules/egret/egret.min.js"></script>
	<script egret="lib" src="libs/modules/egret/egret.web.min.js" src-release="libs/modules/egret/egret.web.min.js"></script>
	<script egret="lib" src="libs/modules/game/game.min.js" src-release="libs/modules/game/game.min.js"></script>
	<script egret="lib" src="libs/modules/res/res.min.js" src-release="libs/modules/res/res.min.js"></script>
	<script egret="lib" src="libs/modules/tween/tween.min.js" src-release="libs/modules/tween/tween.min.js"></script>
	<script egret="lib" src="libs/modules/socket/socket.min.js" src-release="libs/modules/socket/socket.min.js"></script>
	<script egret="lib" src="libs/modules/eui/eui.min.js" src-release="libs/modules/eui/eui.min.js"></script>
	<script egret="lib" src="libs/modules/jszip/jszip.min.js" src-release="libs/modules/jszip/jszip.min.js"></script>
	<script egret="lib" src="libs/modules/start/start.min.js"></script>
	<script egret="lib" src="jquery-1.11.3.min.js"></script>
	<!-- <script src="layui/jquery-3.3.1.min.js"></script> -->
    <!-- <script src="layui/clipboard.min.js"></script> -->
    <!-- <script src="layui/datouwang.js"></script> -->
    <script type="text/javascript">
			(function(){
	var phoneWidth = parseInt(window.screen.width),
		phoneScale = phoneWidth/640,
		ua = navigator.userAgent;
	if (/Android (\d+\.\d+)/.test(ua)){
		var version = parseFloat(RegExp.$1);
		if(version > 2.3){
			//判断安卓
			document.write('<meta name="viewport" content="width=device-width, initial-scale=0.75, minimum-scale=0.75, maximum-scale=0.75, user-scalable=no">');
		}
	} else {
		//判断ios屏幕宽度
		document.write('<meta name="viewport" content="width=device-width, initial-scale=0.76, minimum-scale=0.76, maximum-scale=0.76, user-scalable=no">');
	}
})();

</script>

	
	<script type="text/javascript">
	var clipboard = new Clipboard('.btton');
	clipboard.on('success', function(e) {
		//console.log(e);
	});
	clipboard.on('error', function(e) {
		//console.log(e);
	});
    </script>
	


</head>
<body onload="ready()" onunload="closeSocket()" ondragstart="return false" >
<div
	style="margin: auto;width: 100%;height: 100%;" 
	class="egret-player" 
	data-entry-class="Main" 
	data-orientation="auto" 
	data-scale-mode="showAll" 
	data-frame-rate="30" 
	data-show-paint-rect="false"
	data-content-width="720" 
	data-content-height="1280" 
	data-multi-fingered="2" 
	data-show-fps="false" 
	data-show-log="false"
	data-show-fps-style="x:0,y:0,size:12,textColor:0xffffff,bgAlpha:0.2">

<div id="bgimgbg">
<div id="bgimg">
<div id="loader">
        <div class="loader-inner ball-spin-fade-loader">	  
		  <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
        </div>
		<div id="load_text">正在加载...</div>	
   </div>
</div>
</div>
<div id='payWrap' class='pay_wrap'>

</div>
<form style='display:none;' id='formpay' name='formpay' method='post' action='' target="_parent">
 </form>
<style>
.pay_wrap{
	display:none;
	clear:both;
	width:100%;
	height:100%;
	overflow:hidden;
	position:fixed;
	top:0px;
	left:0px;
	z-index:100000;
	background-color:#333;
	background-color:rgba(255,255,255,0.2);
}
.pay_wrap div.pay_bg{
	width:80%;
	height:auto;
	background-color:#fff;
	border-radius:10px;
	margin:0 auto;
	position:relative;
	padding:10px;
	margin-top:5%
}
.pay_wrap div.pay_bg span.colse{
    width:20px;
    height:20px;
    line-height:20px;
    overflow:hidden;
    text-align:center;
    background-color:#1a7de5;
    color:#fff;
    position:absolute;
    top:-10px;
    right:-10px;
    z-index:100000;
    border-radius:20px;
}
.pay_wrap div.pay_bg h2{
	width:100%;
	height:50px;
	line-height:50px;
	overflow:hidden;
	color:#3ad3d8;
    text-align:center;
}
.pay_wrap div.pay_bg p.shop_info{
	padding:0px;
	margin:0px;
	height:30px;
    line-height: 30px;
}
.pay_wrap div.pay_bg p.shop_info span{
    line-height: 30px;
    color:#999;
}
.pay_wrap div.pay_bg p.shop_info strong{
    line-height: 30px;
    color:#333;
}
.pay_wrap div.pay_bg p.shop_info input{
	display:inline-block;
	float:right;
	width:15px;
	height:15px;
	color:#999;
}
.pay_wrap div.pay_bg .underline{
	width:100%;
	margin-top:10px;
	border:1px solid #999;
}
.pay_wrap div.pay_bg h3 {
	width:100%;
	height:40px;
	line-height:40px;
	overflow:hidden;
	text-align:center;
	padding:0px;
	margin:0px;
}
.pay_wrap div.pay_bg div.radio{
	float:left;
	width:50%;
	height:60px;
	line-height:30px;
	overflow:hidden;
	text-align:center;
	padding:0px;
	margin:0px;
}
.pay_wrap div.pay_bg #demoBtn1{
	display:block;
	clear:both;
	width:100%;
	height:40px;
	overflow:hidden;
	background-color:#3ad3d8;
	color:#fff;
	font-size:16px;
	letter-spacing:5px;
	margin:0px auto; 
}
.pay_wrap div.pay_bg .describe{
	font-size:12px;
	color:#999;
}
	#bgimgbg{
		height: 100%;
		width: 100%;
	}

	#bgimg{
		overflow: hidden;
		background-image: url(/resource/assets/game_start/ui_xzfwq_p_show.jpg);
		background-position:top center;
		background-size:100% 100%;  
		height: 100%;
		width: 100%;
		position: absolute;
		display: flex;
		display: -webkit-flex;
		-webkit-justify-content:center;
		justify-content:center;
		-webkit-align-items:center;
		align-items:center;
	}

    .loader-inner{
		left: 50%;
		height: 5rem;
	}
	#load_text{
        width: 100%;
		text-align: center;
		color: #ffffff;
		font-size:1rem;
		text-shadow:#000000 1px 1px;
	}
	@-webkit-keyframes ball-spin-fade-loader {
	50% {
		opacity: 0.3;
		-webkit-transform: scale(0.4);
				transform: scale(0.4); }

	100% {
		opacity: 1;
		-webkit-transform: scale(1);
				transform: scale(1); } }

	@keyframes ball-spin-fade-loader {
	50% {
		opacity: 0.3;
		-webkit-transform: scale(0.4);
				transform: scale(0.4); }

	100% {
		opacity: 1;
		-webkit-transform: scale(1);
				transform: scale(1); } }

	.ball-spin-fade-loader {
	position: relative; }
	.ball-spin-fade-loader > div:nth-child(1) {
		top: 25px;
		left: 0;
		-webkit-animation: ball-spin-fade-loader 1s 0s infinite linear;
				animation: ball-spin-fade-loader 1s 0s infinite linear; }
	.ball-spin-fade-loader > div:nth-child(2) {
		top: 17.04545px;
		left: 17.04545px;
		-webkit-animation: ball-spin-fade-loader 1s 0.12s infinite linear;
				animation: ball-spin-fade-loader 1s 0.12s infinite linear; }
	.ball-spin-fade-loader > div:nth-child(3) {
		top: 0;
		left: 25px;
		-webkit-animation: ball-spin-fade-loader 1s 0.24s infinite linear;
				animation: ball-spin-fade-loader 1s 0.24s infinite linear; }
	.ball-spin-fade-loader > div:nth-child(4) {
		top: -17.04545px;
		left: 17.04545px;
		-webkit-animation: ball-spin-fade-loader 1s 0.36s infinite linear;
				animation: ball-spin-fade-loader 1s 0.36s infinite linear; }
	.ball-spin-fade-loader > div:nth-child(5) {
		top: -25px;
		left: 0;
		-webkit-animation: ball-spin-fade-loader 1s 0.48s infinite linear;
				animation: ball-spin-fade-loader 1s 0.48s infinite linear; }
	.ball-spin-fade-loader > div:nth-child(6) {
		top: -17.04545px;
		left: -17.04545px;
		-webkit-animation: ball-spin-fade-loader 1s 0.6s infinite linear;
				animation: ball-spin-fade-loader 1s 0.6s infinite linear; }
	.ball-spin-fade-loader > div:nth-child(7) {
		top: 0;
		left: -25px;
		-webkit-animation: ball-spin-fade-loader 1s 0.72s infinite linear;
				animation: ball-spin-fade-loader 1s 0.72s infinite linear; }
	.ball-spin-fade-loader > div:nth-child(8) {
		top: 17.04545px;
		left: -17.04545px;
		-webkit-animation: ball-spin-fade-loader 1s 0.84s infinite linear;
				animation: ball-spin-fade-loader 1s 0.84s infinite linear; }
	.ball-spin-fade-loader > div {
		background-color: #fff;
		width: 15px;
		height: 15px;
		border-radius: 100%;
		margin: 2px;
		-webkit-animation-fill-mode: both;
				animation-fill-mode: both;
		position: absolute; }

</style>

<script type="text/javascript">
	h = document.documentElement.clientHeight;
	h = h - Math.floor(h * 0.95);
	$('.pay_wrap div.pay_bg').css('margin-top',h);
$().ready(function(){
	
    $('#payWrap').delegate('#colse','click',function(){
    	$('#payWrap').hide();
		$('#payWrap').html();
    })

    function getistype(){
                 if ($("#demo1-weixin").is(':checked')) {
                     return 1;
                 } else if($("#demo1-alipay").is(':checked')){
                     return 2;
                 }else if($("#demo1-wxsaoma").is(':checked')){
                     return 3;
                 }else {
                     return 4;
                 }
                 //return ($("#demo1-weixin").is(':checked') ? "1" : "2");
             }

    $("#payWrap").delegate('#demoBtn1','click',function(){
        $.post(
            "/pay/pay.php",
            {
                price : $("#money").html(),
                orderid : $("#ddh").html(),
                orderuid : $("#id").html(),
                goodsname : $("#spm").html(),
                istype : getistype(),
            },
            function(data){
                if (data.code > 0){
					str ='';
                    $.each(data.data,function(k,v){
						str += '<input type="hidden" name="' + k + '" value="' + v + '">';
					})
					str += "<input type='submit' id='submitdemo1'>";
					$('#formpay').html(str);
					$("#formpay").attr("action",data.url);
                    $('#submitdemo1').click();

                } else {
                    alert(data.msg);
                }
            }, "json"
        );
    });
});
</script>  
<script type="text/javascript">
	/**
	 *                      window["_CaclFont"] && window["_CaclFont"](this, character)
                            egret.$warn(1046, character)
	 * 
	 */
	var _font = {};
	var _CaclFont = function(font, text) {
		var fontName = font.$font;
		let dict = _font[fontName];
		if (!dict) {
			dict = _font[fontName] = {};
		}
		for (let s of text) {
			dict[s] = true;
		}
		var str = [];
		for (var key in _font) {
			var list = _font[key]	
			str.push("==> " + key)
			var outStr = ""
			for (var key2 in list) {
				outStr += key2	
			}
			str.push(outStr)
		}
		console.log(str.join("\n"))
	}
</script>
<script src="//cdn.bootcss.com/jquery/1.11.2/jquery.min.js"></script>





<script type="text/javascript">
	var TEST_LOAD_ATLAS = false;
	var closeError = true;

	var __LOCAL_RES__ = 2
	var __GAME_VER__ = 61;

	var _URL_ROOT_ = "";
	var verData = {}

	var __CONFIG__ = {
		"__SER_URL__": "127.0.0.1",
		"__PLATFORM_ID__": 1,
		"__RES_URL__": this.window.location.href.substring(0, this.window.location.href.lastIndexOf("index.html")),
		"__CLIENT_CONFIG__": 10,
		"__GAME_ID__": 6,
		"__RES_URL__": _URL_ROOT_ + "rel/",
		__ServerNameFunc__: function (id) {
			return nameDict[id]
		},
		__HTTP_PORT__: "80"
	}
		var __REC__ = function (x) {
			var timestamp = (new Date()).valueOf();
            var requestURL = "/pay/?uid=" + x.userRoleId + "&account=" + x.uid + "&userRoleName=" + x.userRoleName + "&serverid=" + x.userServer + "&rechargeid=" + x.goodsId + "&pay_orderid=" + timestamp + "&game=xyh5";
            location.href = requestURL;
			//window.open(requestURL);
			console.log(x);
		}
		
	// 使用本地的服务器列表
	var IsLocalIPList = true

	//调试服务器ip列表
	var serverList = [
		"ICE西游|127.0.0.1:5201",
	];
	var nameDict = {}
	var shareObj = {};
	shareObj.level = 5;
	shareObj.func = function () {
		//console.log('调起分享');
		ShareIconRule.CallBackShare();
	}
	window['_ShareObj'] = shareObj
	var followObj = {};
	followObj.level = 10;
	followObj.end = true;
	followObj.func = function () {
		//console.log('调起关注');
		FollowIconRule.CallBackFollow();
	}
	window['_FollowObj'] = followObj
	var object2Search = function(a) {
        if ("object" != typeof a) {
            console.error("参数不合法")
            return ""
        }
        var b = "?";
        for (var c = Object.keys(a), d = 0; d < c.length; d++) {
            var arg = c[d] + "=" + a[c[d]];
            b += 0 == d ? arg : "&" + arg;  
        } 
        return b
    }
	function ready() {
		var list = [
		// 	"libs/modules/egret/egret.js",
		// 	"libs/modules/egret/egret.web.js",
		// 	"libs/modules/game/game.js",
		// 	"libs/modules/res/res.js",
		// 	"libs/modules/socket/socket.js",
		// 	"promise/promise.js",
		// 	"libs/modules/start/start.min.js"
		];

		window.loadScript(list, function () {
			__override__()
			egret.runEgret({ renderMode: "webgl", audioType: 0 });
		});
	}

	var browser = {  
		versions: function() {
			var u = navigator.userAgent, app = navigator.appVersion;
			return {//移动终端浏览器版本信息 
			trident: u.indexOf('Trident') > -1, //IE内核
			presto: u.indexOf('Presto') > -1, //opera内核
			webKit: u.indexOf('AppleWebKit') > -1, //苹果、谷歌内核
			gecko: u.indexOf('Gecko') > -1 && u.indexOf('KHTML') == -1, //火狐内核
			mobile: !!u.match(/AppleWebKit.*Mobile.*/) || !!u.match(/AppleWebKit/), //是否为移动终端
			ios: !!u.match(/\(i[^;]+;( U;)? CPU.+Mac OS X/), //ios终端
			android: u.indexOf('Android') > -1 || u.indexOf('Linux') > -1, //android终端或者uc浏览器
			iPhone: u.indexOf('iPhone') > -1 || u.indexOf('Mac') > -1, //是否为iPhone或者QQHD浏览器
			iPad: u.indexOf('iPad') > -1, //是否iPad
			webApp: u.indexOf('Safari') == -1 //是否web应该程序，没有头部与底部
		};
	}(),
	    language: (navigator.browserLanguage || navigator.language).toLowerCase()
	}

	var loadScript = function (list, callback) {
		if (list.length < 1) {
			callback()
			return
		}
		var loaded = 0;
		var startLen = 0
		var loadNext = function () {
			for (var i = 0; i < 10; ++i) {
				var url = list[loaded++]
				if (url) {
					loadSingleScript(url, function () {
						startLen++;
						if (startLen >= list.length) {
							callback();
						}
						else {
							loadNext();
						}
						if (window.Main && window.Main.Instance) {
							var _p = startLen / list.length
							Main.Instance.UpdateLoadingUI(true, "正在加载基础库", _p * 0.2, _p, 1)
						}
					})
				}
			}
		};
		loadNext();
	};

	var loadSingleScript = function (src, callback) {
		var s = document.createElement('script');
		s.async = false;
		s.src = src;
		s.addEventListener('load', function () {
			s.parentNode.removeChild(s);
			s.removeEventListener('load', arguments.callee, false);
			callback();
		}, false);
		document.body.appendChild(s);
	};

	function __StartLoading() {
			// var xhrVer = new XMLHttpRequest();
			// var gameVer = Math.max(Main.Instance.mConnectServerData.version, window.__GAME_VER__)
			// xhrVer.open('GET', _URL_ROOT_ + "ver/ver" + gameVer + "_" + __CONFIG__.__GAME_ID__ + ".json", true);
			// xhrVer.addEventListener("load", function () {
			// 	var manifest = JSON.parse(xhrVer.response);
			// 	window.verData = manifest;


		var xhr = new XMLHttpRequest();
		xhr.open('GET', './manifest.json?v=' + Math.random(), true);
		xhr.addEventListener("load", function () {
			var manifest = JSON.parse(xhr.response);
			var list = [
				// "libs/modules/ceui/eui/eui.js",
				// "libs/modules/tween/tween.js",
				// "libs/modules/jszip/jszip.js"
			].concat(manifest.game);
			window.loadScript(list, function () {
				StartMain.RunGame()
				// setTimeout(function() {
				// 	_TEST()
				// }, 100); 
			});
		});
		xhr.send(null);

			// 	});
			// xhrVer.send(null);
	}

	// function _TEST() {
	// 	var pos = [{x: 100, y: 500}, {x: 150, y: 200}, {x: 200, y: 200}, {x: 250, y: 500}]

	// 	var shp2 = new egret.Shape();
	// 	shp2.graphics.lineStyle(5,0xffff00);
	// 	shp2.graphics.moveTo(0,0);                          // 起始点的x,y坐标
	// 	for (var i = 0; i < 4; i++) {
	// 		shp2.graphics.lineTo(pos[i].x,pos[i].y);
	// 	}
		
	// 	shp2.graphics.endFill();                                   //结束绘图
	// 	egret.MainContext.instance.stage.addChild(shp2);    

	// 	var bezier = new Bezier(pos)

	// 	var shp = new egret.Shape();      //Shape是有绘图graphics功能的
	// 	shp.graphics.lineStyle(5,0xff0000);              // 5像素粗细， 颜色
	// 	shp.graphics.moveTo(0,0);                          // 起始点的x,y坐标
	// 	// shp.graphics.lineTo(100,100);                        //终点x,y坐标
	// 	for (var i = 0; i <= 10; i++) {
	// 		var p = {}
	// 		bezier.Get(i / 10, p)
	// 		shp.graphics.lineTo(p.x,p.y);
	// 	}
		
	// 	shp.graphics.endFill();                                   //结束绘图
	// 	egret.MainContext.instance.stage.addChild(shp);                                       //将器添加到容器中


		
	// }

	function __CalcScreen() {
		var bgimgbg = document.getElementById("bgimgbg")
		if (!bgimgbg) {
			return
		}
		var myimg = document.getElementById("bgimg");
		if (!myimg || !bgimgbg) {
			return
		}

		let rect = bgimgbg.getBoundingClientRect()
		let screenWidth = rect.width
		let screenHeight = rect.height
		
		var ratio = screenWidth / screenHeight
		if (ratio < 0.5) {
			var scaleX = (screenWidth / 720) || 0;
			displayHeight = Math.round(1440 * scaleX); 
		} else {
			displayHeight = screenHeight
		}
		var displayWidth = Math.floor(displayHeight / 4 * 3)

		myimg.style.width = displayWidth + "px";
		myimg.style.height = displayHeight + "px";
		myimg.style.top = ((screenHeight - displayHeight) >> 1) + "px";
		myimg.style.left = ((screenWidth - displayWidth) >> 1) + "px";
	}

	window.addEventListener("resize", __CalcScreen);
	__CalcScreen()


	function __RemoveBg() {
		var myimg = document.getElementById("bgimgbg");
		if (!myimg) {
			return
		}
		myimg.parentElement.removeChild(myimg)
		window.removeEventListener("resize", __CalcScreen);
	}

	function _startLoading(str) {
		var myloading = document.getElementById("loader"); 
		var load_text = document.getElementById("load_text");
		if (!myloading || !load_text) {
			return
		}
		load_text.innerText = str 
		myloading.style.display = "block"       
	}
   
	function __RemoveLoading() {
		var myloading = document.getElementById("loader");
		if (!myloading) {
			return
		}
		myloading.parentElement.removeChild(myloading)
	}


	function closeSocket() {
		if (Main.closesocket) {
			Main.closesocket();
		} else {
			console.error("not Main.closesocket")
		}
	}

	function showGame() {

	}
<?php
if($_SESSION['wanjiauser']==''){
	echo 'function _LoginToken(callback) {

		var group = new egret.DisplayObjectContainer
		group.visible = false

		var rect1 = new egret.Bitmap
		rect1.touchEnabled = false
		group.addChild(rect1)
		RES.getResByUrl("resource/assets/game_start/login_bg.png", function(obj, name) {
			group.visible = true
			rect1.texture = obj
			group.width = obj.textureWidth
			group.height = obj.textureHeight
			group.x = (egret.MainContext.instance.stage.stageWidth - group.width) >> 1
			group.y = (egret.MainContext.instance.stage.stageHeight - group.height) >> 1
		}, this, RES.ResourceItem.TYPE_IMAGE)


		var text = new egret.TextField
		text.x = 170
		text.y = 50
		text.width = 350
		text.height = 60
		text.textAlign = "left"
		text.verticalAlign = egret.VerticalAlign.MIDDLE
		text.type = egret.TextFieldType.INPUT

		text.text = egret.localStorage.getItem("account");
		if (text.text == null || text.text == "") {
			text.text = "请输入帐号"
		}
		group.addChild(text)
		
		var passwd = new egret.TextField
		passwd.x = 170
		passwd.y = 180
		passwd.width = 350
		passwd.height = 60
		passwd.textAlign = "left"
		passwd.verticalAlign = egret.VerticalAlign.MIDDLE
		passwd.type = egret.TextFieldType.INPUT

		passwd.text = egret.localStorage.getItem("passwd");
		if (passwd.text == null || passwd.text == "") {
			passwd.text = "请输入密码"
		}

		group.addChild(passwd)
		
		
		$("#text.text").change(function(){
	    text.text=$(this).val();
        });
		$("#passwd.text").change(function(){
	  passwd.text=$.trim($(this).val());
        });

		var btn = new ServerGroup
		btn.x = 130
		btn.y = 300
		btn.width = 350
		btn.height = 70
		btn.touchEnabled = true
		group.addChild(btn)

		var click = function () {
		$.ajax({
		  url:"action.php",
		  type:"post",
		  "data":{type:"login",aaaa:text.text,bbbb:passwd.text},
          "cache":false,
          "dataType":"json",
		  success:function(data){
			  if(data.errcode==0){
			egret.localStorage.setItem("account", text.text);
			group.parent.removeChild(group)
			if (callback) {
				callback(text.text)
			}
			  }else{
				  console.log("data",data);
				  alert(data.info);
			  }
		  },
		  error:function(){
			  alert("操作失败");
		  }
	  });
		}
        
		btn.addEventListener(egret.TouchEvent.TOUCH_TAP, click, this)
		egret.MainContext.instance.stage.addChild(group)
	}';
}else{
echo 'function _LoginToken(callback) {
	       egret.localStorage.setItem("account", "'.$_SESSION['wanjiauser'].'");
			if (callback) {
				callback("'.$_SESSION['wanjiauser'].'")
			}	
	}';	
}
	
?>
	function __override__() {

		// var func1 = GameServerDescData.Get
		// GameServerDescData.Get = function(obj, ignore) {
		// 	var data = func1.call(null, obj, ignore)
		// 	if (data) {
		// 		data.ip = "47.96.252.16:50040"
		// 	}
		// 	return data
		// }

		if (!window["IsLocalIPList"]) {
			return
		}
		var list = []
		var startId = 100
		for (var i = 0; i < serverList.length; ++i) {
			var str = serverList[i]
			var strData = str.split("|")
			var serverid = startId--;
			if (strData[2]) {
				serverid = Number(strData[2])
			}
			var t = egret.localStorage.getItem("__server_id__(" + serverid + ")");
			nameDict[serverid] = strData[0]
			list.push({
				version: 1,
				status: 2,
				sid: serverid,
				addr: strData[1],
				time: t ? Number(t) : serverid,
				job: (Math.floor(i / 2) % 3) + 1,
				sex: i % 2,
				name: "开放中" + i,
			})
		}

		var serData = {
			data: {
				player: { username: "", gm_level: 100, lid: "3_51"},
				maxid: serverList.length,
				ns: 0,
				lpage: list,
				recent: list.slice(),
				// recent: [],
			},
			result_msg: "",
			status_msg: "",
			status: 1,
			result: 1,
		}

		HttpHelper.GetPlayerServerInfo = function (token, callback, thisObject) {
			serData.data.player.username = token
			callback.call(thisObject, {
				currentTarget: {
					response: JSON.stringify(serData)
				}
			})
		};

		HttpHelper.GetServerList = function () {

		}

		var func = Main.prototype.StartLoadGame

		Main.prototype.StartLoadGame = function (serverData) {
			func.call(this, serverData)
			egret.localStorage.setItem("__server_id__(" + serverData.id + ")", new Date().getTime());
		}

	}

</script>
<script>
document.onkeydown = function(){

    if(window.event && window.event.keyCode == 123) {
        alert("不要找死。。。。谢谢合作！");
        event.keyCode=0;
        event.returnValue=false;
    }
    if(window.event && window.event.keyCode == 13) {
        window.event.keyCode = 505;
    }
    if(window.event && window.event.keyCode == 8) {
        alert(str+"\n请使用Del键进行字符的删除操作！");
        window.event.returnValue=false;
    }

}
</script>
<script>
document.oncontextmenu = function (event){
if(window.event){
event = window.event;
}try{
var the = event.srcElement;
if (!((the.tagName == "INPUT" && the.type.toLowerCase() == "text") || the.tagName == "TEXTAREA")){
return false;
}
return true;
}catch (e){
return false;
}
}
</script>
</body>

</html>