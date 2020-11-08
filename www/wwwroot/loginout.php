<?php
error_reporting(0);
session_start();
ini_set('date.timezone','Asia/Shanghai');
header("Content-type: text/html; charset=utf8");
unset($_SESSION['wanjiauser']);
unset($_SESSION['wanjiapasswd']);
unset($_SESSION['checkwanjia']);
unset($_SESSION['ggwanjia']);
unset($_SESSION['wanjiaquid']);
unset($_SESSION['wanjiaplayerid']);
unset($_SESSION['wanjiaquname']);
unset($_SESSION['wanjiaservercode']);
unset($_SESSION['wanjiaplayername']);
echo "<script>alert('恭喜您，退出成功！');</script>";
header("refresh:0;url=index.php");
exit();
?>