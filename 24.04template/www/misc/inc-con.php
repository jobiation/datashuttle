<?php

// Set Variables
$dbPath = '/var/cons/inc-db.php'; // Path to the DB connection file
$abPath = 'https://lily.lilytranquillo.com:65443/tea'; // Absolute path to the root of the application utilizing this script.
$startPage = 'index.php';
$thisPage = 'inc-con.php';
$cookie_user_name = 'teauser';
$cookie_pass_name = 'teapass';
$authTable = 'tea_auth'; //Must include a field called user and another field called pass
$attemptsTable = 'attempts'; //This table must include a field called 'username'
$maxAttempts = 6; //If there are this number of attempts in the attempts table, the user will not be granted access.
$attemptsMessage = 'There have been too many attempts with this username. Please wait until the top of next hour. Even if you type the correct password for this username before the top of next hour, you will not be granted access.';

//////////////////////NOTES/////////////////////////////////////////////////////////////////
// Make sure the $authTable and $attemptsTable both exist and contain the appropriate fields
// You must make a cronjob that clears the $attemptsTable table every hour, day, other period of time.
// Include this script at the top of every PHP page in the application
// Put the logout link on every page: <?php echo "<p><a href='". $abPath ."/" .  $startpage . "?logout=1'>Logout</a></p>";
// Do not start a session on pages that include this script
// Create a database connection file and reference it in $dbPath
// Add a mysqli_close($con) statement a the bottom of every PHP page
// Add one or more users to the auth table and make sure their passwords are sha1 hashes

/////////////////////////////////////////////////////////////////////////////////////////////


//Function to detect whether or not the user is using a mobile browser
  function isMobileDevice(){
      $aMobileUA = array(
          '/iphone/i' => 'iPhone',
          '/ipod/i' => 'iPod',
          '/ipad/i' => 'iPad',
          '/android/i' => 'Android',
          '/blackberry/i' => 'BlackBerry',
          '/webos/i' => 'Mobile'
      );
  
      //Return true if Mobile User Agent is detected
      foreach($aMobileUA as $sMobileKey => $sMobileOS){
          if(preg_match($sMobileKey, $_SERVER['HTTP_USER_AGENT'])){
              return true;
          }
      }
      //Otherwise return false..
      return false;
  }

// Start session
  session_start();
  
// Logout
  if($_GET['logout'] == 1)
  {
    $_SESSION['user'] = "";
    $_SESSION['pass'] = "";
    $_POST['user'] = "";
    $_POST['pass'] = "";
    $_COOKIE[$cookie_user_name] = "";
    $_COOKIE[$cookie_pass_name] = "";
    unset($_POST['user']);
    unset($_POST['pass']);
    unset($_SESSION['user']);
    unset($_SESSION['pass']);
    setcookie($cookie_user_name, NULL, -1, "/");
    setcookie($cookie_pass_name, NULL, -1, "/");
    unset($_COOKIE[$cookie_user_name]);
    unset($_COOKIE[$cookie_pass_name]);
  }

// Set cookies
  if($_POST['rememberme'] == "on")
  {
    //echo "Remember me block executed. ";
    setcookie($cookie_user_name, strtolower($_POST['user']), time() + (86400 * 3650), "/");
    setcookie($cookie_pass_name, sha1($_POST['pass']), time() + (86400 * 3650), "/");
  }

// Set Username
  if(isset($_COOKIE[$cookie_user_name]))
  {
    $user = $_COOKIE[$cookie_user_name];
  }
  elseif(isset($_SESSION['user']))
  {
    $user = $_SESSION['user'];
  }
  else
  {
    $user = strtolower($_POST['user']);
  }
  
// Set Password
  if(isset($_COOKIE[$cookie_pass_name]))
  {
    $pass = $_COOKIE[$cookie_pass_name];
  }
  elseif(isset($_SESSION['pass']))
  {
    $pass = $_SESSION['pass'];
  }
  else
  {
    if($_POST['pass'] == NULL || $_POST['pass'] == "")
    {
      $pass == "";
    }
    else
    {
      $pass = sha1($_POST['pass']);
    }
  }


if($user == "" || $pass == "") //This code executes if the username and password variables are not set
{
    echo "<!DOCTYPE html>
    <head>
    <title>Login</title>
    <style>";
      
    echo "td.left{font-weight:900;text-align:right;}";
    echo "table{margin: 0  auto;}";
    echo "h1{text-align:center;}";
    
    if(isMobileDevice())
    {
      echo "body{font-size:300%}";
      echo "input{font-size:100%}";
    }

    echo "</style>
    </head><body>
	  <h1>Login Form</h1>
	  <form action='"  . $abPath . "/" . $startPage . "' method='post'>
    <table>
    <tr>
      <td class='left'>Username: </td>
      <td><input type='text' name='user' /></td>
    </tr>
    <tr>
      <td class='left'>Password: </td>
      <td><input type='password' name='pass' /></td>
    </tr>
    <tr>
      <td>&nbsp;</td>
      <td><input type='submit' value='Login' /></td>
    </tr>
    <tr>
      <td class='left'>Remember Me: </td>
      <td><input type='checkbox' name='rememberme' /></td>
    </tr>
    </table>
    </form>";
    
    if($_GET['failed'] == 1)
    {
      echo "<p>Login Failed.</p>";
    }
    elseif($_GET['failed'] == 2)
    {
      echo "<p>" . $attemptsMessage . "</p>";
    }

  echo "</body></html>";
  exit();

}
else //This code executes if the username and password variables are set.
{
  //Connect to DB
    include($dbPath);

  //Make sure there have not been too many attempts
    $attemptsSel = mysqli_query($con,"SELECT username FROM $attemptsTable WHERE username = '$user'");
    if(mysqli_num_rows($attemptsSel) >= $maxAttempts)
    {
      mysqli_close($con);
      header("location:$abPath/$thisPage?failed=2"); //Failed value of 2 means the account is locked.
      exit();
    }
    
  //Check if auth is successful
    $authSel = mysqli_query($con,"SELECT user,pass FROM $authTable WHERE user = '$user' AND pass = '$pass'");
  
    if(mysqli_num_rows($authSel) > 0)
    {
      $_SESSION['user'] = $user;
      $_SESSION['pass'] = $pass;
      unset($_POST['user']);
      unset($_POST['pass']);
    }
    else
    {
      mysqli_query($con,"INSERT INTO $attemptsTable (username) VALUES ('$user')");
      mysqli_close($con);
      header("location:$abPath/$thisPage?failed=1");
      exit();
    }
}

?>
