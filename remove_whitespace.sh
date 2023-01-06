args=("$@");
echo Striping whitspace from all files in ${args[0]};
for file in ./${args[0]}/*;
do [ -f "$file" ] && mv "$file" "`echo $file|tr -d '[:space:]'`";
done
