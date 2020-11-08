<?php
error_reporting(0);
session_start();
ini_set('date.timezone','Asia/Shanghai');
header("Content-type: text/html; charset=utf8");
//---------------------------------------站点信息--------------------------------------
$order=isset($_GET['order'])?$_GET['order']:"gm";
//---------------------------------------MYSQL配置信息--------------------------------------
function mysqlinfo($lx){ //mysql信息
	$dbinfo=array(
	'dbip'=>'127.0.0.1', //数据库IP
    'dbuser'=>'root', // 数据库帐号
    'dbpwd'=>'471355795', //数据库密码
	'dbname'=>'user', //数据库名称
	'gmcode'=>'111',
	'serverip'=>'182.61.41.188',//外网IP
	'serverport'=>'80',
	'gmqq'=>'1103928888',
	);
	return $dbinfo["$lx"];
}
$dbip=mysqlinfo(dbip); //数据库IP
$dbuser=mysqlinfo(dbuser); // 数据库帐号
$dbpwd=mysqlinfo(dbpwd); //数据库密码
$dbname=mysqlinfo(dbname); //数据库名称
$gmcode=mysqlinfo(gmcode);
$serverip=mysqlinfo(serverip);
$serverport=mysqlinfo(serverport);
$gmqq=mysqlinfo(gmqq);
$key="b2986fe8d4a653727a7d74693402b837";
$bl=1;
$isrecharge=true;
$opendaili=false;
$checkgameid=11444;
//$payurl="https://xy.90ai.top/";
$payurl="http://a.yjcard.com/Payment/Group/2dc17c9be5e173ac";
$list = array(
    "1"=>array('10元','10'),
    "2"=>array('20元','20'),
    "3"=>array('30元','30'),
	"4"=>array('50元','50'),
	"5"=>array('100元','100'),
	"6"=>array('200元','200'),
	"7"=>array('300元','300'),
	"8"=>array('400元','400'),
	"9"=>array('500元','500'),
	"10"=>array('600元','600'),
	"11"=>array('800元','800'),
	"12"=>array('1000元','1000'),
	"13"=>array('1200元','1200'),
	"14"=>array('1500元','1500'),
	"15"=>array('1800元','1800'),
	"16"=>array('2000元','2000'),
	"17"=>array('3000元','3000'),
	"18"=>array('5000元','5000'),
	"19"=>array('月卡','30'),
	"20"=>array('周卡','7'),
	"38"=>array('终身卡','200'),
);
//---------------------------------------MYSQL配置信息--------------------------------------
function SafeSql($value){//过滤sql语句
	return htmlspecialchars(str_replace('\\', '', $value), ENT_QUOTES, "UTF-8", false);
}
function SafeRequest($key, $mode, $type=0){//过滤post和get传递的参数
	$magic = get_magic_quotes_gpc();
	switch($mode){
		case 'post':
			$value = isset($_POST[$key]) ? $magic ? trim($_POST[$key]) : addslashes(trim($_POST[$key])) : NULL;
			break;
		case 'get':
			$value = isset($_GET[$key]) ? $magic ? trim($_GET[$key]) : addslashes(trim($_GET[$key])) : NULL;
			break;
	}
	return $type ? $value : htmlspecialchars(str_replace('\\'.'\\', '', $value), ENT_QUOTES, "UTF-8", false);
}	
function getip(){
	if(isset($_SERVER['REMOTE_ADDR']) && $_SERVER['REMOTE_ADDR'] && strcasecmp($_SERVER['REMOTE_ADDR'], 'unknown')){
		$ip = $_SERVER['REMOTE_ADDR'];
	}elseif(getenv('HTTP_CLIENT_IP') && strcasecmp(getenv('HTTP_CLIENT_IP'), 'unknown')){
		$ip = getenv('HTTP_CLIENT_IP');
	}elseif(getenv('HTTP_X_FORWARDED_FOR') && strcasecmp(getenv('HTTP_X_FORWARDED_FOR'), 'unknown')){
		$ip = getenv('HTTP_X_FORWARDED_FOR');
	}elseif(getenv('REMOTE_ADDR') && strcasecmp(getenv('REMOTE_ADDR'), 'unknown')){
		$ip = getenv('REMOTE_ADDR');
	}
	preg_match("/[\d\.]{7,15}/", isset($ip) ? $ip : NULL, $match);
	return isset($match[0]) ? $match[0] : 'unknown';
}
	?>