<?php 
include_once "config.php";
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0">
    <title>ICE游戏</title>
    <link rel="stylesheet" href="layui/css/layui.css" media="all">
    <style>
        body {
            margin: 10px;
        }

        .demo-carousel {
            height: 250px;
            line-height: 250px;
            text-align: center;
        }
		img{
 width:auto;
 height:auto;
 max-width:100%;
 max-height:100%;
}
body{background: url(resource/assets/game_start/_ui_loding_show.jpg) #fff top center no-repeat;}

.layui-field-title{ border: none;}
.layui-container{ width: 96%; max-width: 450px;}
.layui-text em, .layui-word-aux{ color: #fff !important; font-weight: bold;}
a{ color: #fff; font-weight: bold; }
#a1{margin-top: 340px;}
a:hover{ color: #fff;font-weight: bold;}
@media only screen and (max-width:600px ) {
	body{ background-size:cover ;}
	#a1 {
    margin-top: 130px;
}
}
.layui-tab-brief>.layui-tab-title .layui-this{ font-weight: bold;}
.layui-form-item{ text-align: center;}
    </style>
</head>

<body>
<!--<div class="layui-col-xs12 layui-col-md6">-->
 <!--<div class="layui-carousel" id="test1">
  <div carousel-item="">
   <div><p class="layui-bg-green demo-carousel">欢迎来到涅槃游戏!</p></div>
  </div>
</div>-->
    <div id="a1" class="layui-tab layui-tab-brief"  lay-filter="demo">
     <fieldset class="layui-elem-field layui-field-title">
  <div class="layui-form layui-form-pane">
  <div class="layui-field-box">
<!--begin--> 
 <div class="layui-container fly-marginTop">
  <div class="fly-panel fly-panel-user">
    <div class="layui-tab layui-tab-brief">
	<ul class="layui-tab-title">
        <li><a href="index.php">登入</a></li>
        <li class="layui-this">注册</li>
      </ul>
      <div class="layui-form layui-tab-content" id="LAY_ucm" style="padding: 20px 0;">
        <div class="layui-tab-item layui-show">
          <div class="layui-form layui-form-pane">
              <div class="layui-form-item">
			  <label for="L_qq" class="layui-form-label">QQ号码</label>
                <div class="layui-input-inline" name="name" placeholder="QQ">
                  <input type="text" id="qq" name="qq" required lay-verify="required" placeholder="您唯一的密码找回凭证" autocomplete="off" class="layui-input">
                </div>
   
              </div>

              </div>
              <div class="layui-form-item">
                <label for="L_username" class="layui-form-label">帐号</label>
                <div class="layui-input-inline">
                  <input type="text" id="username" name="username" required lay-verify="required" placeholder="输入2到10个字符" autocomplete="off" class="layui-input">
                </div>
              </div>
              <div class="layui-form-item">
                <label for="L_pass" class="layui-form-label">密码</label>
                <div class="layui-input-inline">
                  <input type="password" id="pass" name="pass" required lay-verify="required" placeholder="输入6到16个字符" autocomplete="off" class="layui-input">
                </div>
              </div>
              <div class="layui-form-item">
                <label for="L_repass" class="layui-form-label">确认密码</label>
                <div class="layui-input-inline">
                  <input type="password" id="repass" name="repass" required lay-verify="required" placeholder="输入6到16个字符" autocomplete="off" class="layui-input">
                </div>
              </div>
              <div class="layui-form-item">
                <label for="L_vercode" class="layui-form-label">验证码</label>
                <div class="layui-input-inline">
                  <input type="text" name="vercode" id="vercode" required lay-verify="required" placeholder="请输入后面显示的验证码" autocomplete="off" class="layui-input">
                </div>
                <div class="layui-form-mid">
                  <span style="color: #c00;"><img src="captcha.php?action=NUMBER" id="gvcode" onclick="javascript:this.src=this.src+'?time='+Math.random();" alt=""></span>
                </div>
              </div>
              <div class="layui-form-item">
               <button class="layui-btn" id="submit" name="submit" lay-filter="*">立即注册</button>
              </div>
          </div>
        </div>
      </div>
    </div>
  </div>

</div>


    
    <script src="layui/layui.js"></script>
	<script src='jquery-1.10.1.min.js'></script>
   <script>
layui.use(['laydate', 'laypage', 'layer', 'table', 'carousel', 'upload', 'element'], function(){
  var laydate = layui.laydate //日期
  ,laypage = layui.laypage //分页
  layer = layui.layer //弹层
  ,table = layui.table //表格
  ,carousel = layui.carousel //轮播
  ,upload = layui.upload //上传
  ,element = layui.element; //元素操作 

    //提示框
layer.msg('<br>最新游戏请关注', {
    time: 5000, //50s后自动关闭
    btn: ['知道了']
  });   
            //底部信息

        }); 
 var username='';
 var pass='';
 var vercode='';
 var qq='';
 var repass='';
 $('#username').change(function(){
	 username=$(this).val();
  });
 $('#pass').change(function(){
	 pass=$(this).val();
  });
  $('#vercode').change(function(){
	 vercode=$(this).val();
  });
   $('#repass').change(function(){
	 repass=$(this).val();
  });
  $('#qq').change(function(){
	 qq=$(this).val();
  });
$('#submit').click(function(){
	if(username==''){
		layer.msg('账号不能为空');
		return false;
	}
	if(pass==''){
		layer.msg('密码不能为空');
		return false;
	}
	if(vercode==''){
		layer.msg('验证码不能为空');
		return false;
	}
	if(qq=='' || isNaN(qq))
	{
	layer.msg('QQ输入错误');
		return false;
	}
	if(pass!=repass){
	layer.msg('两次输入的密码不一致');
		return false;
	}
	layer.msg('正在为您提交注册中，请稍候');
	  $.ajax({
		  url:'action.php',
		  type:'post',
		  'data':{type:'reg',username:username,pass:pass,repass:repass,qq:qq,vercode:vercode,order:"<?php echo $order;?>"},
          'cache':false,
          'dataType':'json',
		  success:function(data){
			  console.log('data',data);
			  layer.msg(data.info);
			  if(data.errcode==0){
				setTimeout(function () {location.href=data.url + "?order=<?php echo $order;?>";}, 1000);   
			  }
		  },
		  error:function(){
			  layer.msg('操作失败');
		  }
	  });
  });
     

     
     
    </script>
</body>

</html>
