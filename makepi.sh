#!/bin/sh

create_task2()
{
	hostname=$1
	ip=$2 # should be of format: 192.168.1.100
	dns=$3 # should be of format: 192.168.1.1

	echo "#!/bin/sh

		# Change the hostname
		sudo sed -i s/raspberrypi/$hostname/g /etc/hosts;
		sudo hostnamectl --transient set-hostname $hostname;
		sudo hostnamectl --static set-hostname $hostname;
		sudo hostnamectl --pretty set-hostname $hostname;

		# Set the static ip
		sudo cat <<EOT >> /etc/dhcpcd.conf
		interface eth0
		static ip_address=$ip/24
		static routers=$dns
		static domain_name_servers=[8.8.8.8,8.8.4.4]
		EOT" > /home/pi/tasks/task2.sh;
}

create_task1() {
	echo '#!/bin/sh

		echo "LOG: started task1.sh"
		# Install Docker
		curl -x http://proxy.ufu.br:3128 -sSL get.docker.com > /home/pi/tasks/getDocker.sh;
		sh /home/pi/tasks/getDocker.sh >> /home/pi/log.txt && \
		  sudo usermod pi -aG docker
		rm /home/pi/tasks/getDocker.sh;

		# Disable Swap
		sudo dphys-swapfile swapoff && \
		  sudo dphys-swapfile uninstall && \
		  sudo update-rc.d dphys-swapfile remove
		echo Adding " cgroup_enable=cpuset cgroup_enable=memory" to /boot/cmdline.txt
		sudo cp /boot/cmdline.txt /boot/cmdline_backup.txt
		# if you encounter problems, try changing cgroup_memory=1 to cgroup_enable=memory.
		orig="$(head -n1 /boot/cmdline.txt) cgroup_enable=cpuset cgroup_memory=1"
		echo $orig | sudo tee /boot/cmdline.txt

		# Add repo list and install kubeadm
		curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
		  echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list && \
		  sudo apt-get update && \
		sudo apt-get install -y kubeadm
		echo "LOG: just run install kubeadm"' > /home/pi/tasks/task1.sh;
}

set_ufu_proxy()
{
	if [ "$( grep 'proxy.ufu.br' /etc/profile )" = "" ]; then
		echo '
			export https_proxy="http://proxy.ufu.br:3128"
			export http_proxy="http://proxy.ufu.br:3128"
			export ftp_proxy="http://proxy.ufu.br:3128"
		' | sudo tee -a /etc/profile;
	fi;

	if [ "$( grep 'proxy.ufu.br' /etc/apt/apt.conf.d/10proxy )" = "" ]; then
		echo 'Acquire::http::Proxy "http://proxy.ufu.br:3128/";' | sudo tee /etc/apt/apt.conf.d/10proxy;
	fi;
}

main_make_pi()
{
	if [ "$(ls /home/pi | grep tasks)" = "" ]; then
		crontab -r;
		(crontab -l 2>/dev/null; echo "@reboot sleep 40 && sh /home/pi/makepi.sh") | crontab -;
		set_ufu_proxy;
		mkdir /home/pi/tasks;
		create_task1;
		echo "LOG: just created task 1" >> /home/pi/log.txt;
		create_task2 $1 $2 $3;
		echo "LOG: just created task 2" >> /home/pi/log.txt;
		echo "LOG: rebootting now" >> /home/pi/log.txt;
		sudo shutdown -r now >> /home/pi/log.txt;
	else
		script_to_run=$(echo $(ls /home/pi/tasks/ | sort)" " | cut -d ' ' -f 1);
		if [ "$script_to_run" = "" ]; then
			rm -rf /home/pi/tasks;
			echo "LOG: just removed /home/pi/tasks" >> /home/pi/log.txt;
			crontab -r;
		else
			echo "LOG: start to run $script_to_run" >> /home/pi/log.txt;
			sh /home/pi/tasks/$script_to_run >> /home/pi/log.txt 2>&1;
			echo "LOG: just executed $script_to_run" >> /home/pi/log.txt;
			rm -f /home/pi/tasks/$script_to_run;
			echo "LOG: rebootting now" >> /home/pi/log.txt;
			sudo shutdown -r now >> /home/pi/log.txt;
		fi;
	fi;
}

main_make_pi $1 $2 $3