1. 原文地址：<http://leafo.net/posts/creating_an_image_server.html>

   总结的image server 
##########

我们将要用到OpenResty<http://openresty.org/>, 一个Niginx的加强分支版本。我们也需要写一点点的Lua去实现我们想要的功能。最后，我们使用这个Lua ImageMagick binding<https://github.com/leafo/magick>. 如果你对这些内容不熟悉，那也ok，我会从草稿开始向你展示如何得到这一切。

什么是图片处理服务器

一个图片处理服务是一个网络应用，它获取一个图片路径和一组处理操作，然后返回被处理过的图片。

一个例子就是用户头像图片。如果你让你的用户上传它们自己的图片，然后可能给出一些不同尺寸和格式的图片。当显示图片时，在不同的页面你需要很多不同尺寸。为了避免预先调整，你只需要一个指定URL使用一个图片处理服务去立即获取你需要的图片尺寸。

另外，如果一个缩放后的图片URL被多次请求，那么应该对这个图片进行缓存，这样的话就可以立即返回给用户。

首先，
这个项目的第一步是去设计URL结构。在这个教程中我会使用下面的形式。

/images/SIGNATURE/SIZE/PATH

给定一张图片leafo.jpg以及所需的尺寸，我们可能需要这样的URL

/images/abcd123/100×100/leafo.png

你应该注意到我已经讲一个签名包含在URL里了。我们会使用一些基本密码学来确保陌生人无法请求任何尺寸的图片。由于图片处理会消耗很多CPU，所以这是一个很重要的考虑。如果有人写一个恶意脚本遍历很多不同尺寸的图片，这将会让你的CPU受到负载过载攻击

这个签名是一个密码功能运行一部分URL（尺寸和路径）和密钥的返回结果。为了验证这个请求URL有效，你需要执行一个简单的断言。

assert(calculate_signature(“100×100/leafo.png”) == “abcd123″)

最后需要提一下图片资源和缓存。对于简单的应用，图片会直接从本地硬盘获取。虽然完全有可能从外部获取，比如amazon S3或者其他URLs,在这个教程中不会讨论。

改变过的图片被缓存在硬盘，缓冲过期这不涉及。这对大多数情况已经足够了。

其次，安装 OpenResty
你可以到这里下载OpenResty的最新版本 http://openresty.org/#Download你可以在官方网站找到更加详细的安装说明书。

$ ./configure --with-luajit
$ make
$ make install

OpenResty本身附带Lua，所以最后的组件就是 ImageMagic Binding了，
如果你已经很熟悉Lua了，你可以使用LuaRocks来安装。

luarocks install –server=http://rocks.moonscript.org magick

如果不是，可以直接用<https://github.com/rodsong/image-server-OpenResty.git>下的magick.lua。

###########


2. 配置

其中需要注意的有，
   1），我在本地安装的时候不是root用户，安装openresty，需要sudo
   2），打开cache，openresty中已经包含该模块 
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
   4）, images 文件夹下的文件当前用户一定要有可读权限（以为忽略了这一点，所以无法生成图片，至使我本地无法运行，所以基本上1天没进展）
    local source_fname = images_dir .. path

	-- make sure the file exists，and can be read.
	local file = io.open(source_fname)

	if not file then
 	 return_not_found()
	end

	file:close()
      这几行确认文件是否存在。在Lua中我们可以通过open一个文件来检查这个文件是否可读。如果文件文件不能打开我们终止。这里我们不需要读文件，所以把文件关闭。

  5), 生成图片
	local dest_fname = cache_dir .. ngx.md5(size .. "/" .. path) .. "." .. ext

	-- resize the image
	local magick = require("magick")
	magick.thumb(source_fname, size, dest_fname)
dest_fname被设置为和我们在Nginx配置中搜索一样的hashed name。文件可以被Nginx的后续的try_files<http://wiki.nginx.org/HttpCoreModule#try_files>自动找到。
目前请求已经被验证，现在是时候缩放了。我们传递尺寸字符串到Magick的thumb方法。它提供了不错的语法用于不同类型的重定义大小和分割，像100 X 100用于重定义大小，10*10 + 5 + 5用于分割。

ngx.exec(ngx.var.request_uri)
现在图片已经写入，我们准备显示到浏览器。这里我触发一个请求到当前location。 request_uri。通常这会触发一个循环错误，但是因为我们写到了缓存文件， try_files会返回文件并跳过Lua脚本。

6），重点提示，所有的×.lua 要有可执行权限，所有图片要有可写权限。
     签名可以运行 localhost:8080/gen/XXX 得到，相见gen_url.lua文件注释。
      nginx.conf文件要打开，/gen/*
       location ~ ^/gen/.*$ {
      content_by_lua_file "gen_url.lua";
     }
7），运行服务
	在启动服务前，你需要方式一些图片到images目录。

	在运行下面这些命令行前，我们需要进入到想要运行服务的目录里面。
	创建目录：
   	$mkdir cache
	初始化文件配置：
	$mkdir logs
	$touch logs/error.log
	开始启动服务
        sudo $/usr/local/openresty/nginx/sbin/nginx -p “$(pwd)” -c “nginx.conf”

	假设服务已经开始，我们现在访问服务。举个例子，如果你有一个图片 leafo.jpg 你可以重定义大小通过下面这个URL http://localhost/images/LMzEhc_nPYwX/80×80/leafo.jpg

8），最后的注意点

	这就是所有的东西了。在nginx.conf中做一些小调整你的服务就可以启动了。

	这里有一些你额外需要做的事情：

	如果你已经有安装了一个Nginx，你可以把这段代码集成进去而不需要另外独立跑一个Nginx进程

	如果你使用另一个Web应用程序来跑图片服务，你需要在你的应用内部写calculate_signature函数用来产生验证URLs.

	如果你关心不再使用的图片尺寸缓存消耗了太多空间，你可以考虑创建一个系统删除不再使用的缓存条目。
   
   
   
最后，由于image server经常会跟java web联合调用，所以DataEncryptUtil.java是java
签名生成文件。
   



