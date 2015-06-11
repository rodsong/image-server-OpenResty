
因为防火墙的原因所以在github上留了本次备份。openpesty 是基于nginx的代理服务器，利用其高并发，速度快的特点可以做很多事情。
	
####################
总结 image server 
####################

本例用到OpenResty<http://openresty.org/>, 一个Niginx的加强分支版本。和Lua脚本实现图片处理功能。

图片处理服务是一个网络应用，对图片进行一系列操作然后返回被处理过的图片。

如果你让用户上传它们自己的图片。当显示图片时，在不同的页面需要很多不同尺寸。为了避免预先调整，你只需要一个指定URL使用一个图片处理服务去立即获取你需要的图片尺寸。

另外，如果一个缩放后的图片URL被多次请求，那么应该对这个图片进行缓存，这样的话就可以立即返回给用户。

####################
首先
####################
这个项目的第一步是去设计URL结构。

/images/SIGNATURE/SIZE/PATH

给定一张图片test.jpg以及所需的尺寸，我们可能需要这样的URL

/images/<SIGN>/100×100/test.png

SIGN标签是为了防止图片被恶意调用消耗过多CPU，防止攻击。

LUA 脚本中有对访问加密的校验，详见serve_image.lua

请求的图片会被缓存到cache目录中 nginx try_files 会判断是否已存在如果存在则直接应用指定尺寸的图片。

####################
其次，安装 ngx_openresty-1.7.4.1.tar.gz
####################
你可以到这里下载OpenResty的最新版本 http://openresty.org/#Download你可以在官方网站找到更加详细的安装说明书。

# ./configure --with-luajit
# make
# make install

详见 install steps.txt

####################
配置
####################

其中需要注意的有，
   1），我在本地安装的时候不是root用户，安装openresty，需要sudo
   2），nginx 端口设置 nginx.conf
   server {
    listen 8080;  
    lua_code_cache on;
   3），签名规则（lua）
      local function calculate_signature(str)
       return ngx.encode_base64(ngx.hmac_sha1(secret, str))
              :gsub("[+/=]", {["+"] = "-", ["/"] = "_", ["="] = ","})
              :sub(1,12)
       end
    这个函数使用密钥为我们的URL签名。我选取HMAC-SHA1的base64编码结果的前12各字符。
    此外我使用 gsub 将在URL中有特殊含义的字符转换以避免潜在的URL编码问题。
   4）,images 文件夹下的文件当前用户一定要有可读权限（以为忽略了这一点，至使我本地无法运行）
   5）, 原始图片要保存到images目录中

   6），重点提示，所有的×.lua 要有可执行权限，所有图片要有可写权限。
     
   7），运行服务及测试
	在启动服务前，你需要放置一些图片到images目录。

	在运行下面这些命令行前，我们需要进入到想要运行服务的目录里面。
	创建目录：
   	$mkdir cache
	初始化文件配置：
	$mkdir logs
	$touch logs/error.log
    sh start.sh 启动服务
	 
	访问 http://localhost:8080/gen/200x200/leafo.jpg 将会得到一个返回值例如 images/ajycOFftuYtC/200x200/leafo.jpg
	该值就是请求图片的路径。 
    继续访问 http://localhost:8080/images/ajycOFftuYtC/200x200/leafo.jpg

    8），最后，由于image server经常会跟java web联合调用，所以DataEncryptUtil.java是java签名生成文件。
   



