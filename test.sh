function fun1(){
  echo "this is fun"
}

function fun2(){
  local res=$(fun1)
  echo $res
}

fun2
