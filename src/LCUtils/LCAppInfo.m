@import CommonCrypto;

#import "LCAppInfo.h"
#import "LCUtils.h"
#import "Shared.h"
#import "src/Utils.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@implementation LCAppInfo
- (instancetype)initWithBundlePath:(NSString*)bundlePath {
	self = [super init];
	self.isShared = false;
	if (self) {
		_bundlePath = bundlePath;
		_infoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Info.plist", bundlePath]];
		_info = [NSMutableDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/LCAppInfo.plist", bundlePath]];
		if (!_info) {
			_info = [[NSMutableDictionary alloc] init];
		}
		if (!_infoPlist) {
			_infoPlist = [[NSMutableDictionary alloc] init];
		}

		// migrate old appInfo
		if (_infoPlist[@"LCPatchRevision"] && [_info count] == 0) {
			NSArray* lcAppInfoKeys = @[
				@"LCPatchRevision", @"LCOrignalBundleIdentifier", @"LCDataUUID", @"LCJITLessSignID", @"LCExpirationDate", @"LCTeamId", @"isJITNeeded", @"isLocked",
				@"doSymlinkInbox", @"bypassAssertBarrierOnQueue", @"signer"
			];
			for (NSString* key in lcAppInfoKeys) {
				_info[key] = _infoPlist[key];
				[_infoPlist removeObjectForKey:key];
			}
			[_infoPlist writeToFile:[NSString stringWithFormat:@"%@/Info.plist", bundlePath] atomically:YES];
			[self save];
		}

		// fix bundle id and execName if crash when signing
		/*if (_infoPlist[@"LCBundleIdentifier"]) {
			_infoPlist[@"CFBundleExecutable"] = _infoPlist[@"LCBundleExecutable"];
			_infoPlist[@"CFBundleIdentifier"] = _infoPlist[@"LCBundleIdentifier"];
			[_infoPlist removeObjectForKey:@"LCBundleExecutable"];
			[_infoPlist removeObjectForKey:@"LCBundleIdentifier"];
			[_infoPlist writeToFile:[NSString stringWithFormat:@"%@/Info.plist", bundlePath] atomically:YES];
		}*/

		_autoSaveDisabled = false;
	}
	return self;
}

- (void)setBundlePath:(NSString*)newBundlePath {
	_bundlePath = newBundlePath;
}

- (NSMutableArray*)urlSchemes {
	// find all url schemes
	NSMutableArray* urlSchemes = [[NSMutableArray alloc] init];
	int nowSchemeCount = 0;
	if (_infoPlist[@"CFBundleURLTypes"]) {
		NSMutableArray* urlTypes = _infoPlist[@"CFBundleURLTypes"];

		for (int i = 0; i < [urlTypes count]; ++i) {
			NSMutableDictionary* nowUrlType = [urlTypes objectAtIndex:i];
			if (!nowUrlType[@"CFBundleURLSchemes"]) {
				continue;
			}
			NSMutableArray* schemes = nowUrlType[@"CFBundleURLSchemes"];
			for (int j = 0; j < [schemes count]; ++j) {
				[urlSchemes insertObject:[schemes objectAtIndex:j] atIndex:nowSchemeCount];
				++nowSchemeCount;
			}
		}
	}

	return urlSchemes;
}

- (NSString*)version {
	NSString* version = _infoPlist[@"CFBundleShortVersionString"];
	if (!version) {
		version = _infoPlist[@"CFBundleVersion"];
	}
	if (version) {
		return version;
	} else {
		return @"Unknown";
	}
}

- (NSString*)bundleIdentifier {
	NSString* ans = _infoPlist[@"CFBundleIdentifier"];
	if (ans) {
		return ans;
	} else {
		return @"Unknown";
	}
}

- (NSString*)dataUUID {
	return _info[@"LCDataUUID"];
}

- (void)setDataUUID:(NSString*)uuid {
	_info[@"LCDataUUID"] = uuid;
	[self save];
}

- (NSString*)bundlePath {
	return _bundlePath;
}

- (NSMutableDictionary*)info {
	return _info;
}

- (void)save {
	if (!_autoSaveDisabled) {
		[_info writeToFile:[NSString stringWithFormat:@"%@/LCAppInfo.plist", _bundlePath] atomically:YES];
	}
}

- (void)preprocessBundleBeforeSiging:(NSURL*)bundleURL completion:(dispatch_block_t)completion {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// Remove faulty file
		[NSFileManager.defaultManager removeItemAtURL:[bundleURL URLByAppendingPathComponent:@"Geode"] error:nil];
		// Remove PlugIns folder
		[NSFileManager.defaultManager removeItemAtURL:[bundleURL URLByAppendingPathComponent:@"PlugIns"] error:nil];
		// Remove code signature from all library files
		if ([self signer] == AltSign) {
			[LCUtils removeCodeSignatureFromBundleURL:bundleURL];
		}

		dispatch_async(dispatch_get_main_queue(), completion);
	});
}

- (void)patchExecAndSignIfNeedWithCompletionHandler:(void (^)(bool success, NSString* errorInfo))completetionHandler
									progressHandler:(void (^)(NSProgress* progress))progressHandler
										  forceSign:(BOOL)forceSign {
	// NSFileManager *fm = [NSFileManager defaultManager];
	NSString* appPath = self.bundlePath;
	NSString* infoPath = [NSString stringWithFormat:@"%@/Info.plist", appPath];
	NSMutableDictionary* info = _info;
	NSMutableDictionary* infoPlist = _infoPlist;
	if (!info) {
		completetionHandler(NO, @"Info.plist not found");
		return;
	}

	// Update patch
	int currentPatchRev = 5;
	if ([info[@"LCPatchRevision"] intValue] < currentPatchRev) {
		//[[LCPath bundlePath] URLByAppendingPathComponent:@"com.robtop.geometryjump.app/GeometryJump"].path;
		NSString* execPath = [NSString stringWithFormat:@"%@/%@", appPath, _infoPlist[@"CFBundleExecutable"]];
		/*NSString *backupPath = [NSString stringWithFormat:@"%@/%@_GeodePatchBackUp", appPath, _infoPlist[@"CFBundleExecutable"]];
		NSError *err;
		[fm copyItemAtPath:execPath toPath:backupPath error:&err];
		[fm removeItemAtPath:execPath error:&err];
		[fm moveItemAtPath:backupPath toPath:execPath error:&err];*/
		NSString* error = LCParseMachO(execPath.UTF8String, ^(const char* path, struct mach_header_64* header) { LCPatchExecSlice(path, header); });
		if (error) {
			completetionHandler(NO, error);
			return;
		}
		info[@"LCPatchRevision"] = @(currentPatchRev);
		/*NSString* cachePath = [appPath stringByAppendingPathComponent:@"zsign_cache.json"];
		forceSign = YES;
		if([fm fileExistsAtPath:cachePath]) {
			NSError* err;
			[fm removeItemAtPath:cachePath error:&err];
		}*/
		[self save];
	}

	if (!LCUtils.certificatePassword) {
		completetionHandler(YES, nil);
		return;
	}

	int signRevision = 1;

	NSDate* expirationDate = info[@"LCExpirationDate"];
	NSString* teamId = info[@"LCTeamId"];
	if (expirationDate && [teamId isEqualToString:[LCUtils teamIdentifier]] &&
		[[[NSUserDefaults alloc] initWithSuiteName:[LCUtils appGroupID]] boolForKey:@"LCSignOnlyOnExpiration"] && !forceSign) {
		if ([expirationDate laterDate:[NSDate now]] == expirationDate) {
			// not expired yet, don't sign again
			completetionHandler(YES, nil);
			return;
		}
	}

	// We're only getting the first 8 bytes for comparison
	NSUInteger signID;
	if (LCUtils.certificateData) {
		uint8_t digest[CC_SHA1_DIGEST_LENGTH];
		CC_SHA1(LCUtils.certificateData.bytes, (CC_LONG)LCUtils.certificateData.length, digest);
		signID = *(uint64_t*)digest + signRevision;
	} else {
		completetionHandler(NO, @"Failed to find signing certificate. Please refresh your store and try again.");
		return;
	}

	// Sign app if JIT-less is set up
	if ([info[@"LCJITLessSignID"] unsignedLongValue] != signID || forceSign) {
		NSURL* appPathURL = [NSURL fileURLWithPath:appPath];
		[self preprocessBundleBeforeSiging:appPathURL completion:^{
			// We need to temporarily fake bundle ID and main executable to sign properly
			NSString* tmpExecPath = [appPath stringByAppendingPathComponent:@"Geode.tmp"];
			if (!info[@"LCBundleIdentifier"]) {
				// Don't let main executable get entitlements
				[NSFileManager.defaultManager copyItemAtPath:NSBundle.mainBundle.executablePath toPath:tmpExecPath error:nil];

				infoPlist[@"LCBundleExecutable"] = infoPlist[@"CFBundleExecutable"];
				infoPlist[@"LCBundleIdentifier"] = infoPlist[@"CFBundleIdentifier"];
				infoPlist[@"CFBundleExecutable"] = tmpExecPath.lastPathComponent;
				infoPlist[@"CFBundleIdentifier"] = NSBundle.mainBundle.bundleIdentifier;
				[infoPlist writeToFile:infoPath atomically:YES];
			}
			infoPlist[@"CFBundleExecutable"] = infoPlist[@"LCBundleExecutable"];
			infoPlist[@"CFBundleIdentifier"] = infoPlist[@"LCBundleIdentifier"];
			[infoPlist removeObjectForKey:@"LCBundleExecutable"];
			[infoPlist removeObjectForKey:@"LCBundleIdentifier"];

			void (^signCompletionHandler)(BOOL success, NSDate* expirationDate, NSString* teamId, NSError* error) =
				^(BOOL success, NSDate* expirationDate, NSString* teamId, NSError* _Nullable error) {
					dispatch_async(dispatch_get_main_queue(), ^{
						if (success) {
							info[@"LCJITLessSignID"] = @(signID);
						}

						// Remove fake main executable
						[NSFileManager.defaultManager removeItemAtPath:tmpExecPath error:nil];

						if (success && expirationDate) {
							info[@"LCExpirationDate"] = expirationDate;
						}
						if (success && teamId) {
							info[@"LCTeamId"] = teamId;
						}
						// Save sign ID and restore bundle ID
						[self save];
						[infoPlist writeToFile:infoPath atomically:YES];
						completetionHandler(success, error.localizedDescription);
					});
				};

			__block NSProgress* progress;

			Signer currentSigner = [[Utils getPrefs] boolForKey:@"LCCertificateImported"] ? ZSign : [self signer];
			switch (currentSigner) {
			case ZSign:
				progress = [LCUtils signAppBundleWithZSign:appPathURL completionHandler:signCompletionHandler];
				break;
			case AltSign:
				progress = [LCUtils signAppBundle:appPathURL completionHandler:signCompletionHandler];
				break;
			default:
				completetionHandler(NO, @"Signer Not Found");
				break;
			}

			if (progress) {
				progressHandler(progress);
			}
		}];

	} else {
		// no need to sign again
		completetionHandler(YES, nil);
		return;
	}
}

- (bool)doSymlinkInbox {
	if (_info[@"doSymlinkInbox"] != nil) {
		return [_info[@"doSymlinkInbox"] boolValue];
	} else {
		return NO;
	}
}
- (void)setDoSymlinkInbox:(bool)doSymlinkInbox {
	_info[@"doSymlinkInbox"] = [NSNumber numberWithBool:doSymlinkInbox];
	[self save];
}

- (bool)ignoreDlopenError {
	if (_info[@"ignoreDlopenError"] != nil) {
		return [_info[@"ignoreDlopenError"] boolValue];
	} else {
		return NO;
	}
}
- (void)setIgnoreDlopenError:(bool)ignoreDlopenError {
	_info[@"ignoreDlopenError"] = [NSNumber numberWithBool:ignoreDlopenError];
	[self save];
}

- (bool)bypassAssertBarrierOnQueue {
	if (_info[@"bypassAssertBarrierOnQueue"] != nil) {
		return [_info[@"bypassAssertBarrierOnQueue"] boolValue];
	} else {
		return NO;
	}
}
- (void)setBypassAssertBarrierOnQueue:(bool)enabled {
	_info[@"bypassAssertBarrierOnQueue"] = [NSNumber numberWithBool:enabled];
	[self save];
}

- (Signer)signer {
	return (Signer)[((NSNumber*)_info[@"signer"])intValue];
}
- (void)setSigner:(Signer)newSigner {
	_info[@"signer"] = [NSNumber numberWithInt:(int)newSigner];
	[self save];
}

- (NSArray<NSDictionary*>*)containerInfo {
	return _info[@"LCContainers"];
}

- (void)setContainerInfo:(NSArray<NSDictionary*>*)containerInfo {
	_info[@"LCContainers"] = containerInfo;
	[self save];
}

@end
