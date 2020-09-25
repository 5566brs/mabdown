#!/bin/bash

if [[ ! "$1" =~ ^https?://((www.)?myairbridge.com|mab.to)/.* ]]
then
    echo "argument not match myairbridge link"
    exit -1
fi

fileid=`basename $1`

url="$1" && echo "$1" | grep mab.to -q && url=` curl -sI "$1" | grep -i Location `

echo "$url" | grep link -q && method=Upload
echo "$url" | grep email -q && method=Email

details=`mktemp`

curl -s "https://api.myairbridge.com/common/Get"$method"Detail/" \
-H 'Content-Type: application/json; charset=UTF-8' \
--data 'r={"action":"Get'$method'Detail","lang":"en","data":{"id":"'$fileid'"}}&p=json&v=4.0'>$details

location_id=`cat $details | node -pe 'JSON.parse(fs.readFileSync(0)).data.location_id' `

createticketdataupload=`mktemp`

cat $details | node -e 'var c=JSON.parse(fs.readFileSync(0)); let del = ({id,name,path}) => ({id,name,path}); let files_map=[]; c.data.files.forEach(x=>{files_map.push(del(x))}); let t={"action":"CreateTicket2","lang":"en","data":{"files_map":files_map,"password":"","src":4,"srcId":c.data.link_id}}; console.log("r="+JSON.stringify(t)+"&p=json&v=4.0")'>$createticketdataupload

createticket=`curl -s https://download-$location_id.myairbridge.com/api/CreateTicket2/ -H 'Content-Type: application/json; charset=UTF-8' --data "@$createticketdataupload"`
#"r=$s&p=json&v=4.0"

status=`echo $createticket | node -pe 'JSON.parse(fs.readFileSync(0)).data.ok'`
 
if [ $status = "false" ] ; then echo $createticket >&2 ; exit -1 ;fi

createdownload=`mktemp`

obj='{"action":"createDownload","lang":"en","data":{"channel":"","content_id":x.id,"download_type":"file","source":"html5_beta","ticket":d.data.ticket}}'
cat $details | node -e "var c=JSON.parse(fs.readFileSync(0)); var d=$createticket; c.data.files.forEach(x=>{var t=$obj; console.log(JSON.stringify(t))})">$createdownload

createdownloaddata=`mktemp` 
cat $createdownload | while read line; do curl -s https://download-$location_id.myairbridge.com/api/createDownload/ -H 'Content-Type: application/json; charset=UTF-8' --data "r=$line">>$createdownloaddata; done

cat $createdownloaddata | grep -o 'http[^"]*' | sed 's/\\//g'
