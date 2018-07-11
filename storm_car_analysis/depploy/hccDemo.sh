#/bin/bash
function getSoft()
{
  if [ ! -f "upload_kafka_tool.tar.gz" ];then
    echo "start download kafka_tool"
    wget http://mapreduceservice.obs-website.cn-north-1.myhwclouds.com/demo/upload_kafka_tool.tar.gz
    tar -zxf upload_kafka_tool.tar.gz
  fi
  
  if [ ! -f "car_analysis.jar" ];then
    echo "start download car_analysis"
    wget http://mapreduceservice.obs-website.cn-north-1.myhwclouds.com/demo/car_analysis.jar
  fi
  
  if [ ! -f "apache-tomcat-9.0.10.zip" ];then
    echo "start download tomcat"
    wget https://obs-devcloud.obs-website.cn-north-1.myhwclouds.com/apache-tomcat-9.0.10.zip
	unzip /opt/apache-tomcat-9.0.10.zip
  fi
  
  if [ ! -f "/opt/apache-tomcat-9.0.10/webapps/hccDemo.war" ];then
    echo "start download hccDemo"
    wget https://mapreduceservice.obs-website.cn-north-1.myhwclouds.com/demo/hccDemo.war
    mv /opt/hccDemo.war /opt/apache-tomcat-9.0.10/webapps/
  fi
}


function modifyConf()
{
  if [ -f "/opt/upload_kafka_tool/dis.properties" ];then
    sed -i "s/192.168.0.220:9092,192.168.0.246:9092,192.168.0.242:9092/${coreIP}:9092/g" /opt/upload_kafka_tool/dis.properties
  fi
  
  if [ -f "/opt/apache-tomcat-9.0.10/conf/server.xml" ];then
    sed -i "s/8005/9005/g" /opt/apache-tomcat-9.0.10/conf/server.xml
    sed -i "s/8080/9090/g" /opt/apache-tomcat-9.0.10/conf/server.xml
    sed -i "s/8009/9009/g" /opt/apache-tomcat-9.0.10/conf/server.xml
  fi
}

function startProducer()
{
  echo "start producer"
  nohup /opt/upload_kafka_tool/bin/linux/startProducer.sh >/opt/producer.log 2>&1 &
}

function startStorm()
{
  echo "start Storm"
  nohup storm jar car_analysis.jar com.huawei.storm.hcc.SearchXCarTopology xcar input_topic fake_car_output ${coreIP}:9092 200 10 30 30 >/opt/storm_xcar.log 2>&1 &
  nohup storm jar car_analysis.jar com.huawei.storm.hcc.SearchCarSumTopology xcar-sum input_topic sum_car_output ${coreIP}:9092 60 5 >/opt/storm_xcarsum.log 2>&1 &
}

function startTomcat()
{
  echo "start tomcat"
  chmod 755 /opt/apache-tomcat-9.0.10/bin/*
  sh /opt/apache-tomcat-9.0.10/bin/startup.sh
  sleep 10
  sed -i "s/ip1:9092,ip2:9092,ip3:9092/${coreIP}:9092/g" /opt/apache-tomcat-9.0.10/webapps/hccDemo/WEB-INF/classes/app.conf
}

function main()
{
  masterIP=`cat /etc/hosts |grep master1 | awk '{print $1}'`
  coreIP=`cat /etc/hosts |grep core | awk '{print $1}' | head -1`
  source /opt/client/bigdata_env
  cd /opt/
  getSoft
  modifyConf
  
  if [ ! -n "$(ps -ef | grep startProducer.sh |grep -v grep )" ]; then
    startProducer
  fi
  
  if [ ! -n "$(storm list |grep xcar)" ]; then
    startStorm
  fi
  
  if [ ! -n "$(ps -ef | grep tomcat-9.0 |grep -v grep )" ]; then
    startTomcat
  fi

}

main