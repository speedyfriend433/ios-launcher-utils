#import <Foundation/Foundation.h>

typedef void (^LCParseMachOCallback)(const char *path, struct mach_header_64 *header);

typedef NS_ENUM(NSInteger, Store){
    SideStore,
    AltStore
};

typedef NS_ENUM(NSInteger, Signer){
    AltSign = 0,
    ZSign = 1
};

NSString *LCParseMachO(const char *path, LCParseMachOCallback callback);
void LCPatchAddRPath(const char *path, struct mach_header_64 *header);
void LCPatchExecSlice(const char *path, struct mach_header_64 *header);
void LCPatchLibrary(const char *path, struct mach_header_64 *header);
void LCChangeExecUUID(struct mach_header_64 *header);
void LCPatchAltStore(const char *path, struct mach_header_64 *header);

@interface PKZipArchiver : NSObject

- (NSData *)zippedDataForURL:(NSURL *)url;

@end

@interface LCUtils : NSObject

+ (void)validateJITLessSetupWithSigner:(Signer)signer completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;
+ (NSURL *)archiveIPAWithBundleName:(NSString*)newBundleName error:(NSError **)error;
+ (NSURL *)archiveTweakedAltStoreWithError:(NSError **)error;
+ (NSData *)certificateData;
+ (NSString *)certificatePassword;

+ (BOOL)askForJIT;
+ (BOOL)launchToGuestApp;
+ (BOOL)launchToGuestAppWithURL:(NSURL *)url;

+ (void)removeCodeSignatureFromBundleURL:(NSURL *)appURL;
+ (NSProgress *)signAppBundle:(NSURL *)path completionHandler:(void (^)(BOOL success, NSDate* expirationDate, NSString* teamId, NSError *error))completionHandler;
+ (NSProgress *)signAppBundleWithZSign:(NSURL *)path completionHandler:(void (^)(BOOL success, NSDate* expirationDate, NSString* teamId, NSError *error))completionHandler;
+ (BOOL)isAppGroupAltStoreLike;
+ (Store)store;
+ (NSString *)teamIdentifier;
+ (NSString *)appGroupID;
+ (NSString *)appUrlScheme;
+ (NSURL *)appGroupPath;
+ (NSString *)storeInstallURLScheme;
+ (NSString *)getVersionInfo;

// ext 
+ (NSUserDefaults *)appGroupUserDefault;
+ (void)signFilesInFolder:(NSURL *)url signer:(Signer *)signer onProgressCreated:(void (^)(NSProgress *))onProgressCreated;
+ (NSString *)getStoreName;
+ (NSString *)getAppRunningLCScheme:(NSString *)bundleId;
+ (NSString *)getContainerUsingLCScheme:(NSString *)containerName;
@end
