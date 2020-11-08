<?php
include_once "config.php";
if(!isset($_POST['type'])){
 $return = array('errcode' => 1, 'info' => '系统提示：未知错误',);
 exit(json_encode($return));	
}
switch ($_POST['type']){
case 'login':
$username = SafeRequest("aaaa","post");  
$password = SafeRequest("bbbb","post");  
$pwd=md5($password);
if(!isset($username) || !isset($password) || $username=='' || $password==''){
$return = array('errcode' => 1, 'info' => '系统提示：帐号密码不能为空',);
 exit(json_encode($return));	
}
$preg='/^[A-Za-z0-9_\x{4e00}-\x{9fa5}]+$/u';
$preg2="/^(select|SHOW FULL COLUMNS FROM|SHOW TABLES FROM|SHOW CREATE TABLE|drop|update|DROP|Select|UPDATE|AND|and|update)/i";
$string=$username.$password;
if(!preg_match($preg,$string) || preg_match($preg2,$string)){
$return = array('errcode' => 1, 'info' => '系统提示：帐号或密码只能数字和英文字母',);
exit(json_encode($return));	
}
if(strlen($username) < 2 || strlen($username) > 10 || strlen($password) < 6 || strlen($password) > 16){
$return = array('errcode' => 1, 'info' => '系统提示：帐号或密码的长度不正确',);
exit(json_encode($return));
}
$mysqli=new mysqli($dbip,$dbuser,$dbpwd,$dbname,'3306');
if(!$mysqli){
$return = array('errcode' => 1, 'info' => '系统提示：数据库连接失败',);
exit(json_encode($return));	
}
$mysqli->set_charset('utf8');
$query = $mysqli->prepare("select * from `users` where `account`=? and `password`=? limit 1");
$query->bind_param('ss', $username,$pwd);
$query->execute();
$result = $query->get_result();
if($result==null || $result->num_rows==0){
$return = array('errcode' => 1, 'info' => '系统提示：帐号或者密码错误',);
exit(json_encode($return));	
}
$row = mysqli_fetch_array($result);
$check=md5($row['account'].$row['password']);
$isban=$row['ban'];
$userid=$row['id'];
if($isban=='1'){
		$return = array('errcode' => 1, 'info' => '系统提示：您已被封号',);
		 unset($_SESSION);
         session_destroy();
		 exit(json_encode($return));	
		}
$userip=getip();
$lasttime=date("Y-m-d H:i:s",time());
$query = $mysqli->prepare("UPDATE users SET lastloginip=?,lastlogintime=? WHERE account =? and password=? limit 1");
$query->bind_param('ssss', $userip,$lasttime,$username,$pwd);
$query->execute();	
$gg = time();
		$_SESSION['wanjiauser'] = $username;
		$_SESSION['wanjiapasswd'] = $password;
		$_SESSION['checkwanjia']=$check;
		$_SESSION['ggwanjia']=$gg;
		unset($_SESSION['CheckCode']);
$url="index.php";
$return = array('errcode' => 0, 'info' => '系统提示：登录成功','url' =>$url);
exit(json_encode($return));	
break;
case 'reg':
$code=SafeRequest("vercode","post");  
if(!isset($code) || $code<>strtolower($_SESSION['CheckCode'])){
$return = array('errcode' => 1, 'info' => '系统提示：验证码错误',);
 exit(json_encode($return));
}
$username = SafeRequest("username","post");   
$password =SafeRequest("pass","post"); 
$password2= SafeRequest("repass","post"); 
$qq  = SafeRequest("qq","post"); 
$k_order=SafeRequest("order","post"); 
$pwd=md5($password);
if(!isset($username) || !isset($password) || $username=='' || $password=='' || !isset($password2) || $password2==''){
$return = array('errcode' => 1, 'info' => '系统提示：帐号密码不能为空',);
exit(json_encode($return));		
}
if($password<>$password2){
$return = array('errcode' => 1, 'info' => '系统提示：两次输入的密码不一致',);
exit(json_encode($return));	
}
$preg='/^[A-Za-z0-9_\x{4e00}-\x{9fa5}]+$/u';
$preg2="/^(select|SHOW FULL COLUMNS FROM|SHOW TABLES FROM|SHOW CREATE TABLE|drop|update|DROP|Select|UPDATE|AND|and|update)/i";
$string=$username.$password;
if(!preg_match($preg,$string) || preg_match($preg2,$string)){
$return = array('errcode' => 1, 'info' => '系统提示：帐号或密码只能数字和英文字母',);
exit(json_encode($return));		
}
if(strlen($username) < 2 || strlen($username) > 10 || strlen($password) < 6 || strlen($password) > 16){
$return = array('errcode' => 1, 'info' => '系统提示：帐号或密码的长度不正确',);
exit(json_encode($return));		
}
if(!is_numeric($qq) || $qq==''){
$return = array('errcode' => 1, 'info' => '系统提示：请输入正确的QQ',);
exit(json_encode($return));		
}
$mysqli=new mysqli($dbip,$dbuser,$dbpwd,$dbname,'3306');
if(!$mysqli){
$return = array('errcode' => 1, 'info' => '系统提示：数据库连接失败',);
exit(json_encode($return));		
}
$mysqli->set_charset('utf8');
$query = $mysqli->prepare("select * from `users` where `account`=? limit 1");
$query->bind_param('s', $username);
$query->execute();
$result = $query->get_result();
if($result==null || $result->num_rows==0){
$query = $mysqli->prepare("insert into `users` (account,password,qq,reg_time,lastlogintime,lastloginip,k_order) values(?,?,?,?,?,?,?)");
$time=date('Y-m-d H:i:s');
$ip=getip();
$query->bind_param('sssssss', $username,$pwd,$qq,$time,$time,$ip,$k_order);
$query->execute();
if($query){
$url="index.php";
$return = array('errcode' => 0, 'info' => '系统提示：恭喜您注册成功，正在为您加载','url' =>$url);
$gg = time();
$check=md5($username.$pwd);
		$_SESSION['wanjiauser'] = $username;
		$_SESSION['wanjiapasswd'] = $password;
		$_SESSION['checkwanjia']=$check;
		$_SESSION['ggwanjia']=$gg;
		unset($_SESSION['CheckCode']);
exit(json_encode($return));	
}else{
$return = array('errcode' => 1, 'info' => '系统提示：注册失败',);
exit(json_encode($return));	
}		
}else{	
$return = array('errcode' => 1, 'info' => '系统提示：该帐号已经被注册',);
exit(json_encode($return));	
}
break;
default:
$return = array('errcode' => 1, 'info' => '未知错误');
exit(json_encode($return));
break;
}
?>
