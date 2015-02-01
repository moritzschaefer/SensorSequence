#!/bin/sh

#for i in 10 11 12 13 15 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 99 100 101 102 103 137 138 139 140 141 142 143 144 145 146 147 148 149 150 151 152 153 154 185 186 188 189 190 191 192 193 194 195 196 197 199 200 202 204 205 206 207 208 209 211 213 214 215 216 218 220 221 222 223 224 225 228 229 230 231 240 241 249 250 251 252 262 272

nodelist=`cat nodes.txt`
echo nodelist = $nodelist
for i in $nodelist
do
  j=`expr $i + 9000`
 ./tunnel.exp $j&
 sleep 1;
done

echo "Type quit to kill all tunnels";

something="something";

#while [ $something != "quit" ];
#do
#	read something;
	if [ $something = "quit" ]; then
		killall expect;
		exit;
	fi
#done
echo "done"
