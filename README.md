# Gopher support for iOS and macOS!

Add support for the gopher protocol to your project with this NSURLProtocol subclass.

Still a work in progress, but should work for most gopher text pages. No proxy support yet.

More Information about the gopher protocol can be found here [(https://en.wikipedia.org/wiki/Gopher\_%28protocol%29)]

## Basic Usage ##

To use in your own projects, import the GopherURLProtocol class and header into your
project.

```objective-c
#import "GopherURLProtocol.h"
```
Register the class as early in the application execution as possible

```objective-c
[NSURLProtocol registerClass: [GopherURLProtocol class]];
```
After registration, data can be loaded from gopher servers via the regular url methods

```objective-c
NSURL *url = [NSURL URLWithString: @"gopher://gopherpedia.com"];

if (url != nil)
{
    NSData *urlData = [NSData dataWithContentsOfURL: url];
    NSString *outputString = [[NSString alloc] initWithBytes: urlData.bytes
        length: urlData.length encoding: NSUTF8StringEncoding];

    printf("%s", outputString.UTF8String);
}
```

For more information and sample code, check out the XCode project.


## License ##
[BSD (Berkeley Software Distribution) License](http://www.opensource.org/licenses/bsd-license.php).
Copyright (c) 2017, Impending
