# 白嫖clash节点+生成配置文件+启动clash  (az6.sh)
白嫖freenode.openrunner.net的免费节点，然后修改部分配置（见az6.sh中my_cfg变量），并且启动clash。

## 使用说明
1. 安装依赖项目：[clash](https://github.com/Dreamacro/clash)
2. 下载本仓库的az6.sh，和clash程序放在同一个目录下，赋予二者可执行权限。
3. 按照自己的需求自定义az6.sh中my_cfg的配置字段，然后执行az6.sh，看到下面的信息表示启动成功。
![Image](pic.png)
4. 把az6.sh加入到crontab中以实现定时启动，如下面内容可实现每天在14:02执行脚本

```2 14 * * *       /mypath/az6.sh &```

## 其他说明
- 这个网站每天更新节点，推荐每天定时执行一次。（如果当天的节点未发布，脚本会尝试下载前一天的节点文件）
