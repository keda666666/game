<?php 
session_start(); 
//session_register('CheckCode'); 
//PHP4.2以上版本不需要用session_register()注册SESSION变量 
$type='gif'; 
$width= 45; 
$height= 20; 
header("Content-type: image/".$type); 
srand((double)microtime()*1000000); 
if(isset($_GET['action'])){ 
 $randval=randStr(4,$_GET['action']);  
}else{ 
 $randval=randStr(4,''); 
} 
if($type!='gif'&&function_exists('imagecreatetruecolor')){ 
 $im=@imagecreatetruecolor($width,$height); 
}else{ 
 $im=@imagecreate($width,$height); 
} 
$r=Array(225,211,255,223); 
$g=Array(225,236,237,215); 
$b=Array(225,236,166,125); 
$key=rand(0,3); 
$backColor=ImageColorAllocate($im,$r[$key],$g[$key],$b[$key]);//背景色（随机） 
$borderColor=ImageColorAllocate($im,127,157,185);//边框色 
$pointColor=ImageColorAllocate($im,255,170,255);//点颜色 
@imagefilledrectangle($im,0,0,$width - 1,$height - 1,$backColor);//背景位置 
@imagerectangle($im,0,0,$width-1,$height-1,$borderColor); //边框位置 
$stringColor=ImageColorAllocate($im,255,51,153); 
for($i=0;$i<=100;$i++){ 
 $pointX=rand(2,$width-2); 
 $pointY=rand(2,$height-2); 
 @imagesetpixel($im,$pointX,$pointY,$pointColor); 
} 
@imagestring($im,5,5,1,$randval,$stringColor); 
$ImageFun='Image'.$type; 
$ImageFun($im); 
@imagedestroy($im); 
$_SESSION['CheckCode']=$randval; 
function randStr($len=6,$format='ALL'){ 
 switch($format){ 
  case 'ALL'://生成包含数字和字母的验证码 
   $chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'; break; 
  case 'CHAR'://仅生成包含字母的验证码 
   $chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'; break; 
  case 'NUMBER'://仅生成包含数字的验证码 
   $chars='0123456789'; break; 
  default : 
   $chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'; break; 
 } 
 $string=''; 
 while(strlen($string)<$len) 
 $string.=substr($chars,(mt_rand()%strlen($chars)),1); 
 return $string; 
}