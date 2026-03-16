#自动化流程模板

# 1. 创建一个工作库，映射IP库
vlib work
## ！！此处需要修改！！ 将DUT中需要用到的ip库映射到work的逻辑库中，可自由命名。
vmap xpm "X:/xxx/xxx/ip_name"     

# 2. 编译待测试文件和仿真文件
## ！！此处需要修改！！ 将你要编译的.v和.sv都放进来，在同一文件夹的.v如果全部编译，就用*.v代替，.sv也是同理
vlog -work work "X:/xxx/*.v"
vlog -sv -work work "x:/xxx/xxx.sv"
##！！此处需要修改！！ 独立仿真Xilinx工程需要加这一句，其他工程可以删除
vlog -work work "X:/xxx/xxx/glbl.v"

# 3. 开始仿真
##！！此处需要修改！！ tb_xxx需要修改成你的TestBench文件的名称
vsim work.tb_xxx\
-l report.txt -t ps \
##！！此处需要修改！！ "-L ip_name \"中ip_name修改成你添加的ip名字，如果没有ip，那就删除这句话
##每个 -L 后跟一个库名，仿真器会在这些库中搜索设计中引用的模块。
-L ip_name \
-L secureip \
-L simprims_ver \
-L unifast_ver \
-L unimacro_ver \
-L unisims_ver glbl  -vopt -voptargs=+acc

# 4. 添加信号到波形窗口
##！！此处需要修改！！ 和绝对路径不一样，这是一个层级路径：/tb模块名/DUT实例名/具体变量名
##如果全部信号都要添加到波形中看，就用*
add wave -position insertpoint -group "SIM/Group1" /tb_xxx/u_xxx/*

# 5. 运行仿真
run -all


