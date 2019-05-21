#!/bin/bash

if [ $# -ne 3 ]; then
	echo "Usage: filter_timestamp directory y_file x_file";
	exit 1
else
	directory="$1"
	y_name="$2";
	unified_csv="$3";

	cd $directory

	echo $(head -n 1 $y_name) > YFileProcessed.csv;
	echo $(head -n 1 $unified_csv) > XFileProcessed.csv;

	for t in $(tail -n +2 $unified_csv); do
		timestamp=$(echo $t | cut -d ',' -f 1);
		search=$(cat $y_name | grep -m 1 $timestamp);
		if [ "$search" != "" ]; then
			echo "$t" >> XFileProcessed.csv;
			echo "$search" >> YFileProcessed.csv;
		fi
	done
	qtdLinhasX=$(cat XFileProcessed.csv | wc -l);
	qtdLinhasY=$(cat YFileProcessed.csv | wc -l);
	if [ $qtdLinhasX -ne $qtdLinhasY ]; then
		echo "Arquivos com quantidades diferentes de linhas!!!!";
	else
		erros=0;
		echo "Arquivos csvs gerados com sucesso. Iniciando verificacao dos timestamps...";
		readarray xArray < XFileProcessed.csv;
		readarray yArray < YFileProcessed.csv;
		for i in $(seq 2 $qtdLinhasX); do
			xTimestamp=$(echo ${xArray[i]} | cut -d ',' -f 1);
			yTimestamp=$(echo ${yArray[i]} | cut -d ',' -f 1);
			if [ "$xTimestamp" != "$yTimestamp" ]; then
				echo "Linha $i tem diferenca de timestamp: $xTimestamp $yTimestamp" >> ./log.txt;
				erros=$((erros + 1));
			fi
		 done
		echo "Verificacao finalizada. Foram encontrados $erros erros.";
		if [ $erros -ge 1 ]; then
			echo "Verifique o arquivo log.txt";
		fi
	fi
	exit 0
fi
