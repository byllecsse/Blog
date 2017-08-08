[Back](index.md)
# 在Unity中生成二维码的三种方式

二维码不用多说，随着移动端的发展，二维码变得十分普及，移动支付、链接分享、信息识别，其实二维码有很多种类，中国常用的是QR码，常见于共享单车开锁，微信钱包和支付宝的电子支付，转发或者分享一段文本或者图片，这次的项目中用到了手机扫描大屏幕上的二维码，分享游戏战绩，由于unity build apk提供的多种方式，有三种方式可以生成二维码图片。

大概的需求是游戏结束，把要分享的分数、设备号、时间戳和要宣传的网址，合并成一段url，根据这段url生成QR码，这决定了Unity的逻辑作为项目的主导，由Unity来决定何时调用生成二维码，所以在生成二维码时，Android代码都应该作为辅助。



### 用C#生成二维码

http://dev.twsiyuan.com/2017/02/qrcode-generator-in-unity.html



### 将生成二维码的jar导入Unity



### Unity导出Android Project

[ZXing](https://github.com/zxing/zxing)
二维码识别使用的是Google提供的ZXing开源项目，它支持了一系列条形码和二维码的格式, 提供二维码和条形码的扫描。扫描条形码就是直接读取条形码的内容，扫描二维码是按照自己指定的二维码格式进行编码和解码。

###### 记录我的使用步骤



使用Android Studio导入core-3.3.0.jar，复制粘贴jar包进app/libs
