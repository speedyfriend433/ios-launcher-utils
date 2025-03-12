#import "AppDelegate.h"
#import "IntroVC.h"
#import "LCUtils/LCUtils.h"
#import "LCUtils/Shared.h"
#import "RootViewController.h"
#import "Theming.h"
#import "Utils.h"
#import "components/LogUtils.h"
#import <spawn.h>

// https://www.uicolor.io/
@implementation AppDelegate
- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.backgroundColor = [Theming getBackgroundColor];
	if ([[Utils getPrefs] boolForKey:@"CompletedSetup"]) {
		RootViewController* rootViewController = [[RootViewController alloc] init];
		self.window.rootViewController = rootViewController;
	} else {
		IntroVC* introViewController = [[IntroVC alloc] init];
		self.window.rootViewController = introViewController;
	}

	[self.window makeKeyAndVisible];
	return YES;
}

// ext

+ (void)openWebPage:(NSString*)urlStr {
	AppDelegate* delegate = (AppDelegate*)UIApplication.sharedApplication.delegate;
	if (!delegate.openUrlStrFunc) {
		delegate.urlStrToOpen = urlStr;
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{ delegate.openUrlStrFunc(urlStr); });
	}
}

+ (void)setOpenUrlStrFunc:(void (^)(NSString* urlStr))handler {
	AppDelegate* delegate = (AppDelegate*)UIApplication.sharedApplication.delegate;
	delegate.openUrlStrFunc = handler;
	if (delegate.urlStrToOpen) {
		dispatch_async(dispatch_get_main_queue(), ^{
			handler(delegate.urlStrToOpen);
			delegate.urlStrToOpen = nil;
		});
	}
	NSString* storedUrl = [[Utils getPrefs] stringForKey:@"webPageToOpen"];
	if (storedUrl) {
		[[Utils getPrefs] removeObjectForKey:@"webPageToOpen"];
		dispatch_async(dispatch_get_main_queue(), ^{ handler(storedUrl); });
	}
}

+ (void)setLaunchAppFunc:(void (^)(NSString* bundleId, NSString* container))handler {
	AppDelegate* delegate = (AppDelegate*)UIApplication.sharedApplication.delegate;
	delegate.launchAppFunc = handler;
	if (delegate.bundleToLaunch) {
		dispatch_async(dispatch_get_main_queue(), ^{
			handler(delegate.bundleToLaunch, delegate.containerToLaunch);
			delegate.bundleToLaunch = nil;
			delegate.containerToLaunch = nil;
		});
	}
}

+ (void)launchApp:(NSString*)bundleId container:(NSString*)container {
	AppDelegate* delegate = (AppDelegate*)UIApplication.sharedApplication.delegate;
	if (!delegate.launchAppFunc) {
		delegate.bundleToLaunch = bundleId;
		delegate.containerToLaunch = container;
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{ delegate.launchAppFunc(bundleId, container); });
	}
}

- (BOOL)application:(UIApplication*)application openURL:(nonnull NSURL*)url options:(nonnull NSDictionary<UIApplicationOpenURLOptionsKey, id>*)options {
	if ([url.host isEqualToString:@"open-web-page"]) {
		NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
		for (NSURLQueryItem* item in components.queryItems) {
			if ([item.name isEqualToString:@"q"]) {
				NSData* decodedData = [[NSData alloc] initWithBase64EncodedString:item.value options:0];
				if (decodedData) {
					NSString* decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
					if (decodedString) {
						[AppDelegate openWebPage:decodedString];
					}
				}
			}
		}
	} else if ([url.host isEqualToString:@"geode-launch"] || [url.host isEqualToString:@"launch"] || [url.host isEqualToString:@"relaunch"]) {
		[[Utils getPrefs] setValue:[Utils gdBundleName] forKey:@"selected"];
		[[Utils getPrefs] setValue:@"GeometryDash" forKey:@"selectedContainer"];
		[[Utils getPrefs] setBool:NO forKey:@"safemode"];
		if ([url.host isEqualToString:@"relaunch"] && [[Utils getPrefs] boolForKey:@"USE_TWEAK"]) {
			pid_t pid;
			int status;
			// sorry, -9 or itll show crash log...
			const char* args[] = { "killall", "-9", "GeometryJump", NULL };
			int spawnError = posix_spawn(&pid, [Utils getKillAllPath], NULL, NULL, (char* const*)args, NULL);
			if (spawnError != 0)
				return NO;
			if (waitpid(pid, &status, 0) != -1) {
				if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
					[LCUtils launchToGuestApp];
					return NO;
				}
			}
			return NO;
		}
		if ([url.host isEqualToString:@"relaunch"] && [[Utils getPrefs] boolForKey:@"JITLESS"]) {
			LCAppInfo* app = [[LCAppInfo alloc] initWithBundlePath:[[LCPath bundlePath] URLByAppendingPathComponent:@"com.robtop.geometryjump.app"].path];
			app.signer = [[Utils getPrefs] boolForKey:@"USE_ZSIGN"] ? 1 : 0;
			[LCUtils signMods:[[LCPath dataPath] URLByAppendingPathComponent:@"GeometryDash/Documents/game/geode"] force:NO signer:app.signer
				progressHandler:^(NSProgress* progress) {} completion:^(NSError* error) {
					if (error != nil) {
						AppLog(@"Detailed error for signing mods: %@", error);
					}
					[LCUtils launchToGuestApp];
				}];
		} else {
			AppLog(@"Launching Geometry Dash");
			[LCUtils launchToGuestApp];
		}
	} else if ([url.host isEqualToString:@"safe-mode"]) {
		AppLog(@"Launching in Safe Mode");
		[[Utils getPrefs] setValue:[Utils gdBundleName] forKey:@"selected"];
		[[Utils getPrefs] setValue:@"GeometryDash" forKey:@"selectedContainer"];
		[[Utils getPrefs] setBool:YES forKey:@"safemode"];
		[LCUtils launchToGuestApp];
	}
	return NO;
}

- (void)applicationWillTerminate:(UIApplication*)application {
	NSUserDefaults* defaults = [Utils getPrefs];
	[defaults removeObjectForKey:@"selected"];
	[defaults removeObjectForKey:@"selectedContainer"];
	if ([defaults objectForKey:@"LCLastLanguages"]) {
		[defaults setObject:[defaults objectForKey:@"LCLastLanguages"] forKey:@"AppleLanguages"];
		[defaults removeObjectForKey:@"LCLastLanguages"];
	}
}

@end
