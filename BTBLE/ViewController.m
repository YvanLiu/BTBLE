//
//  ViewController.m
//  BTBLE
//
//  Created by 柳玉峰 on 2018/8/23.
//  Copyright © 2018年 柳玉峰. All rights reserved.
//

#import "ViewController.h"

#import <CoreBluetooth/CoreBluetooth.h>

#define M_BLE_NAME @"Gnwee"
#define M_BLE_MAC  @"A4C138050DC2"


@interface ViewController ()<CBCentralManagerDelegate, CBPeripheralDelegate>

/**
 手机设备
 */
@property (nonatomic, strong) CBCentralManager *centralManager;

/**
 外设设备
 */
@property (nonatomic, strong) CBPeripheral *peripheral;

/**
 特征值
 */
@property (nonatomic, strong) CBCharacteristic *characteristic;

/**
 服务
 */
@property (nonatomic, strong) CBService *service;

/**
 描述
 */
@property (nonatomic, strong) CBDescriptor *descriptor;
@end

@implementation ViewController


//MARK: 1.初始化设备
- (void)viewDidLoad {
    [super viewDidLoad];
    // 初始化设备
    self.centralManager =[[CBCentralManager alloc]initWithDelegate:self queue:nil];
}

//MARK: 2. 退出页面后，停止扫描 断开连接
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 停止扫描
    [self.centralManager stopScan];
    // 断开连接
    if(self.centralManager!=nil&&self.peripheral.state==CBPeripheralStateConnected){
        [self.centralManager cancelPeripheralConnection:self.peripheral];
    }
}

//MARK: 3.初始化设备会调用此方法
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBCentralManagerStateUnknown:
            NSLog(@"CBCentralManagerStateUnknown");
            break;
        case CBCentralManagerStateResetting:
            NSLog(@"CBCentralManagerStateResetting");
            break;
        case CBCentralManagerStateUnsupported:
            NSLog(@"CBCentralManagerStateUnsupported");
            break;
        case CBCentralManagerStateUnauthorized:
            NSLog(@"CBCentralManagerStateUnauthorized");
            break;
        case CBCentralManagerStatePoweredOff:
            NSLog(@"CBCentralManagerStatePoweredOff");
            break;
        case CBCentralManagerStatePoweredOn: {
            NSLog(@"CBCentralManagerStatePoweredOn");
            //TODO: 搜索外设
            // services:通过某些服务筛选外设 传nil=搜索附近所有设备
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];
        }
            break;
        default:
            break;
    }
}

//MARK: 4.发现设备回调

/**
 发现设备后调用

 @param central 手机设备
 @param peripheral 外设
 @param advertisementData 外设携带数据
 @param RSSI 信号强度
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"\n设备名称：%@",peripheral.name);
    //TODO: 使用名字判断
    /*
    if ([peripheral.name isEqualToString:M_BLE_NAME]) {
        self.peripheral = peripheral;
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
     */
    //TODO: 使用mac地址判断
    NSData *data  =[advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
    NSString *mac =[[self convertToNSStringWithNSData:data] uppercaseString];// uppercaseString转大写字母
    if([mac rangeOfString:M_BLE_MAC].location != NSNotFound){
        self.peripheral = peripheral;
        // 连接外设
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

//MARK: 5.1 外设连接成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"设备连接成功:%@", peripheral.name);
    // 设置代理
    [self.peripheral setDelegate:self];
    //MARK: 6.1 外设发现服务,传nil代表不过滤
    [self.peripheral discoverServices:nil];
    // 停止扫描
    [self.centralManager stopScan];
}

//MARK: 5.2 外设连接失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"设备连接失败:%@", peripheral.name);
    // 重新从搜索外设开始
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    
}

//MARK: 5.3 丢失连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"设备丢失连接:%@", peripheral.name);
    // 重新从搜索外设开始
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    
}

//MARK: 6.2 发现外设服务回调
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    // 是否获取失败
    if (error) {
        NSLog(@"设备获取服务失败:%@", peripheral.name);
        return;
    }
    for (CBService *service in peripheral.services) {
        self.service = service;
        NSLog(@"设备的服务(%@),UUID(%@),count(%lu)",service,service.UUID,peripheral.services.count);
        //MARK: 7.1 外设发现特征
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

//MARK: 7.2 从服务中发现外设特征的回调
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    
    for (CBCharacteristic *cha in service.characteristics) {
        NSLog(@"\n设备的服务(%@)\n服务对应的特征值(%@)\nUUID(%@)\ncount(%lu)",service,cha,cha.UUID,service.characteristics.count);
        //MARK: 8.1 获取特征对应的描述 会回调didUpdateValueForDescriptor
        [peripheral discoverDescriptorsForCharacteristic:cha];
        //MAKR: 9.1获取特征的值 会回调didUpdateValueForCharacteristic
        [peripheral readValueForCharacteristic:cha];
        // 这里需要和硬件工程师协商好，数据写在哪个UUID里
        if([cha.UUID isEqual:[CBUUID UUIDWithString:@"FFE1"]]){
            self.characteristic = cha;
        } else {
            // 打开外设的通知，否则无法接受数据
            // 这里也是根据项目，和硬件工程师协商好，是否需要打开通知，和打开哪个UUID的通知。
            [peripheral setNotifyValue:YES forCharacteristic:cha];
        }
    }
}

//MARK: 8.2 更新描述值回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error {
    NSLog(@"描述(%@)",descriptor.description);
}


//MARK: 9.2 更新特征值回调，可以理解为获取蓝牙发回的数据
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSString *value = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSLog(@"设备的特征值(%@),获取的数据(%@)",characteristic,value);
    //这里可以在这里获取描述
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"FFE2"]]) {
        NSData *data =characteristic.value;
        NSLog(@"%@",[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
    }
}

//MARK: 通知状态改变回调
-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if(error){
        NSLog(@"改变通知状态");
    }
}

//MAKR: 发现外设的特征的描述数组
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    // 在此处读取描述即可
    for (CBDescriptor *descriptor in characteristic.descriptors) {
        self.descriptor = descriptor;
        NSLog(@"发现外设的特征descriptor(%@)",descriptor);
        [peripheral readValueForDescriptor:descriptor];
    }
}

// MARK: 10.1 发送数据
- (IBAction)openTheDoor:(id)sender {
    NSString *doorStr =@"85019557102018082314450536D9BBAAF5A43B79F1B4639F995E4701DA57AFCDBDD0C866F07995EAB8MAG139A7D4V4B3QE1BQ2E5KETCI0H619OAO8MFA8FD1";
    [self writeData:[doorStr dataUsingEncoding:NSUTF8StringEncoding]];
}

//MARK: 发送数据
-(void)sendDataToBLE:(NSData *)data{
    if(nil != self.characteristic){
        // data: 数据data
        // characteristic: 发送给哪个特征
        // type:     CBCharacteristicWriteWithResponse,  CBCharacteristicWriteWithoutResponse,
        // 这里要跟硬件确认好，写入的特征是否有允许写入，允许用withResponse 不允许只能强行写入，用withoutResponse
        // 或者根据 10.2 回调的error查看一下是否允许写入，下面说
        // 我这里是不允许写入的，所以用了 WithoutResponse
        [self.peripheral writeValue:data forCharacteristic:self.characteristic type:CBCharacteristicWriteWithoutResponse];
    }
}

//MARK: 分段写入
- (void)writeData:(NSData *)data
{
    // 判断能写入字节的最大长度
    int maxValue;
    if (@available(iOS 9.0, *)) {
        // type:这里和上面一样，
        maxValue =(int)[self.peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
    } else {
        // 默认是20字节
        maxValue =20;
    }
    NSLog(@"%i",maxValue);
    for (int i = 0; i < [data length]; i += maxValue) {
        // 预加 最大包长度，如果依然小于总数据长度，可以取最大包数据大小
        if ((i + maxValue) < [data length]) {
            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, maxValue];
            NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
            [self sendDataToBLE:subData];
            // 根据接收模块的处理能力做相应延时
            usleep(10 * 1000);
        }
        else {
            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, (int)([data length] - i)];
            NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
            [self sendDataToBLE:subData];
            usleep(10 * 1000);
        }
    }
}

//MARK: 10.2 发送数据成功回调
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        NSLog(@"写入数据失败:(%@)\n error:%@",characteristic,error.userInfo);
        // 这里用withResponse如果报错："Writing is not permitted."说明设备不允许写入，这个时候要用 WithoutResponse
        // 使用 WithoutResponse的时候，不走这个代理。
        return;
    }
    NSLog(@"写入数据成功:%@",characteristic);
    [peripheral readValueForCharacteristic:characteristic];
}


#pragma mark - ==========================TOOL===========================

//MARK: mac地址解析处理
- (NSString *)convertToNSStringWithNSData:(NSData *)data {
    NSMutableString *strTemp = [NSMutableString stringWithCapacity:[data length]*2];
    const unsigned char *szBuffer = [data bytes];
    for (NSInteger i=0; i < [data length]; ++i) {
        [strTemp appendFormat:@"%02lx",(unsigned long)szBuffer[i]];
    }
    return strTemp;
}

@end
