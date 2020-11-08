declare class WeatherBase {
    _runing: boolean;
    _first: boolean;
    timerFrame: number;
    index: number;
    imageList: egret.Texture[];
    private m_Temp;
    constructor(t: any);
    playWeather(tex: egret.Texture[]): void;
    stopWeather(): void;
    weatherUpdateHandler(time: number): boolean;
    onWeatherInit(): void;
    onWeatherStart(): void;
    onWeatherUpdate(): void;
    onWeatherStop(): void;
}
declare class NoticeUI extends egret.DisplayObjectContainer {
    constructor();
    private bg;
    private m_Label;
    private onAddToStage(event);
    private UpdateNotice(data);
    private _OnClickClose();
    private Close();
    private onResize();
}
declare class GameServerData {
    static readonly PAGE_COUNT: number;
    static MaxId: number;
    static PageData: GameServerPageData[];
    static SelectData: GameServerDescData;
    static Callback: Function;
    static ThisObject: any;
    static HasRecentSvr(): boolean;
    static Init(maxId: number, datas: GameServerDescData[], lastList: GameServerDescData[]): void;
    static GetPageData(page: number): void;
    private static _DoPageData(page, event);
}
declare class GameServerPageData {
    index: number;
    name: string;
    datas: GameServerDescData[];
}
declare class GameServerDescData {
    id: number;
    name: string;
    ip: string;
    status: number;
    version: number;
    GetStatus(): number;
    CanEnter(): boolean;
    static Get(obj: any, ignore?: boolean): GameServerDescData;
}
declare class HttpHelper {
    static GetPlayerServerInfo(token: string, callback: Function, thisObject: any): void;
    static GetServerList(page: number, callback: Function, thisObject: any): void;
    static GetRandomName(serverid: number, sex: number, callback: Function, thisObject: any): void;
    static CheckName(serverid: number, name: string, callback: Function, thisObject: any): void;
    static GetNotice(callback: Function, thisObject: any): void;
    private static m_Set;
    static SendPoint(point: number): void;
    private static Error();
}
declare class LoadingUI extends egret.DisplayObjectContainer {
    private m_Textures;
    constructor();
    private bg;
    private blackBg;
    private m_Label;
    private tipx1;
    private tipx2;
    private tipImg;
    private img01;
    private img01Tag;
    private img01W;
    private img02;
    private img02Tag;
    private img02W;
    private label03;
    private imgWidth;
    private str;
    private s1;
    private e1;
    private s2;
    private e2;
    private t;
    private et;
    private pt;
    private preveTime;
    private mt;
    private NewBar(y);
    private onAddToStage(event);
    private SetBarValue(bar, value, tag);
    private _LoadTexture(index);
    private _Loaded(obj, name);
    Close(): void;
    private Update(time);
    private _OnClick();
    private _UpdatePro(value);
    UpdateText(str: string, p1: number, p2: number, time: number): void;
    SetText(str: string, p1: number, p2: number, time: number): void;
    private onResize();
    getElasticOut(t: number): number;
    sineOut(t: number): number;
}
declare class LoginUI extends egret.DisplayObjectContainer {
    constructor();
    private m_Label;
    private m_NewServerLabel;
    private NewServerBg();
    private NewSelServerBg();
    private NewStarBtn();
    private onAddToStage(event);
    Close(): void;
    SetCurServerName(): void;
    private _OnClickNotice();
    private _OnClickServer();
    private _OnClickLogin();
}
declare class Main extends egret.DisplayObjectContainer {
    mLoadResGroup01: {};
    mLoadResGroup02: {
        "_ui_cjjs_bm_ditu": string;
    };
    mLoadResGroup03: {
        "_notice_res": string;
    };
    mLoadResGroup04: {
        "_notice_res": string;
    };
    mLoadResGroup05: {
        "ui_xzfwq_p_show": string;
    };
    private sheet;
    private m_CurLoadGroup;
    mToken: string;
    static Instance: Main;
    playerServerData: GetPlayerServerInfoData;
    mConnectServerData: GameServerDescData;
    mCreateRoleData: {
        crn: string;
        crji: number;
    };
    UserName: string;
    NoticeStatus: number;
    GmLevel: number;
    lid: string;
    private m_CreateRoleData;
    private m_UIGroup;
    private m_NextStepType;
    private m_CreateRolViewData;
    static $GetThmPath(str: string, thmId: number): string;
    constructor();
    private m_BGImg;
    private onAddToStage(event);
    private _DoGetPlayerServerInfo(event);
    private _DoParsePlayerServerInfo(infostr);
    private _SetNextStep(step);
    private _LoadSheet(jsonName);
    private _LoadGroup(group);
    private _CheckUI(name);
    ShowServerUI(): void;
    ShowNoticeUI(): void;
    ShowCreateUI(data: GameServerDescData): void;
    UpdateLoadingUI(isUpdate: boolean, str: string, p1: number, p2: number, time: number): void;
    ShowLoadingUI(): void;
    private m_LoadingImg;
    private m_TimeOutId;
    private DoShowLoadingImg();
    private ShowLoadingImg();
    private UpdateLoadingImgAnim(timeStamp);
    private HideLoadingImg();
    mUIGroupYPos: number;
    private onResize();
    private m_HasLoading;
    private _CloseView(view);
    ShowGame(): void;
    private _CheckServerState(serverData);
    private m_ConCallback;
    ConnectServer(serverData: GameServerDescData, callback: Function): void;
    StartLoadGame(serverData: GameServerDescData): void;
    private _ClearConData();
    SocketUpdateState(state: number): void;
    GetImg(name: string): egret.Texture;
    GetSingleImg(name: string): egret.Texture;
    private _OnLoadItem(obj, name);
    private _CreateScene();
    /**
     * 创建游戏场景
     */
    private CreateGameScene(nextType);
    static closesocket(): void;
}
interface GetPlayerServerInfoData {
    data: {
        player: {
            username: string;
            gm_level: number;
            lid: string;
        };
        maxid: number;
        ns: number;
        lpage: {
            version: number;
            status: number;
            sid: number;
            addr: string;
        }[];
        recent: {
            job: number;
            sex: number;
            name: string;
            time: number;
            status: number;
            sid: number;
            version: number;
            addr: string;
        }[];
    };
    result_msg: string;
    status_msg: string;
    status: number;
    result: number;
}
declare class TestScreenAdapter extends egret.HashObject implements egret.sys.IScreenAdapter {
    /**
     * @private
     * 计算舞台显示尺寸
     * @param scaleMode 当前的缩放模式
     * @param screenWidth 播放器视口宽度
     * @param screenHeight 播放器视口高度
     * @param contentWidth 初始化内容宽度
     * @param contentHeight 初始化内容高度
     */
    calculateStageSize(scaleMode: string, screenWidth: number, screenHeight: number, contentWidth: number, contentHeight: number): egret.sys.StageDisplaySize;
}
declare class CreateRoleUI extends egret.DisplayObjectContainer {
    private m_ServerData;
    private m_Textures;
    constructor(serverData: GameServerDescData);
    private m_IsRandom;
    private m_TweenList;
    private m_Random;
    private m_GoBtn;
    private m_TextField;
    private m_CurImgIndex;
    private m_Index;
    private m_Job;
    private m_Sex;
    private timeLabel;
    private sex1;
    private sex2;
    private sel1;
    private sel2;
    private roleGroup0;
    private roleGroup1;
    private roleImg0;
    private roleImg1;
    private mSelImg;
    private time;
    private m_CreateThm1();
    private AddSelGroup();
    private onAddToStage(event);
    private _DoFocus();
    private UpdateIndex(value);
    private DoRandom();
    private _DoRandom();
    private m_CheckName;
    private m_CheckIndex;
    private _DoGo();
    private SendPoint(point);
    private _Go(data);
    private _DoRandomName(data);
    private Select(index);
    private UpdateSel();
    private _LoadTexture(index);
    private _Loaded(obj, name);
    private Close();
    private m_LastTime;
    private AddTween(target, prop, duration);
    private Update(timeStamp);
    static circOut(t: number): number;
    private static SetDownState(obj);
}
declare class ServerUI extends egret.DisplayObjectContainer {
    constructor();
    private bg;
    private m_LeftScrollView;
    private m_RightScrollView;
    private PlayerInfo;
    static COLOR: number;
    private onAddToStage(event);
    private DoServerData(page);
    private Close();
    private _LeftClick(index);
    private _RightClick(index);
    static IsNewServer(serverId: number): boolean;
    private _OnClickClose();
    private onResize();
}
declare class ServerScrollView {
    private m_ScrollView;
    private m_Group;
    private m_ItemCls;
    private m_CacheList;
    private m_Datas;
    private m_Click;
    private m_ThisObject;
    constructor(scrollView: egret.ScrollView, itemCls: any, clickFunc: Function, thisObject: any);
    private GetItme();
    private OnChange();
    private _ItemClick(e);
    private m_Index;
    GetSelectIndex(): number;
    SelectIndex(index: number): void;
    private _AddItem(index, forward);
    GetData(index: number): any;
    SetDatas(datas: any[]): void;
}
declare class ServerGroup extends egret.DisplayObjectContainer {
    constructor();
    $hitTest(stageX: number, stageY: number): egret.DisplayObject;
}
declare class ServerUIItem1 extends egret.DisplayObjectContainer {
    static Width: number;
    static Height: number;
    light: egret.Bitmap;
    itemIndex: number;
    private label;
    constructor();
    SetData(data: GameServerPageData): void;
}
declare class ServerUIItem2 extends egret.DisplayObjectContainer {
    static Width: number;
    static Height: number;
    itemIndex: number;
    flagImg: egret.Bitmap;
    hotImg: egret.Bitmap;
    headImg: egret.Bitmap;
    private label;
    Desc: GameServerDescData;
    playername: egret.TextField;
    kuangImg: egret.Bitmap;
    constructor();
    SetData(data: GameServerDescData): void;
    SetHeadData(): void;
}
declare class Socket {
    /** 连接中 */
    static STATUS_CONNECTING: number;
    /** 检验中 */
    static STATUS_CHECKING: number;
    /** 连接生效 */
    static STATUS_COMMUNICATION: number;
    /** 关闭连接 */
    static STATUS_DISCONNECT: number;
    UpdateStateEvent: Function;
    private _socketStatus;
    _host: string;
    _port: number;
    private socket_;
    proxy: {
        onSocketConnected: Function;
        onSocketRead: Function;
        onSocketClose: Function;
        onFinishCheck: Function;
    };
    constructor();
    private static _ins;
    static ins: () => Socket;
    readonly connected: boolean;
    newSocket(): void;
    connectError(): void;
    connect(host: string, port: number): void;
    private Connect(host, port);
    close(): void;
    GetSocketState(): number;
    onSocketConnected(e: any): void;
    private recvPack;
    onSocketRead(e: any): void;
    onSocketClose(e: any): void;
    updateStatus(status: any): void;
    onFinishCheck(newStatus: any, oldStatus: any): void;
    private m_PreHeartBeat;
    private m_ServerTimeCounter;
    private m_HeartBeat;
    private _SendHeartBeat(time);
    sendPack(pack: any): void;
}
declare class WindowData {
    private static m_IsShow;
    static ShowFps(): void;
    static _LoginToken(callback: Function): void;
    static _GetServerAddr(): string;
    static _GetBGImg(): string;
    static _GetStartType(): number;
    static _GetCenterAddr(): string;
    static _GetResAddr(): string;
    static _GetStartResAddr(): string;
    static _GetPlatformId(): number;
    static _MainCls(): string;
    static _DirectLogin(): boolean;
    static _GetServerName(serverId: number): string;
    private static HasClientConfig(index);
    static StartLoading(): void;
    static RemoveBg(): void;
    static IsHttps(): boolean;
    static HttpsPort(): string;
    static HttpPort(): string;
    private static _IsFullScreen;
    /***是否支持全屏 */
    static IsFullScreen(): boolean;
    static Has(value: number, bit: number): boolean;
    static GetThmType(): number;
    static GetDefaultSel(): number;
}
declare class RainLine extends egret.Bitmap {
    autoRotation: boolean;
    sptx: number;
    speedx: number;
    speedy: number;
    targety: number;
    sy: number;
    down: boolean;
    spt: number;
    touchEnabled: boolean;
    type: any;
    isDeath: any;
    sScale: number;
    rotationPlus: number;
    update(): any;
}
declare class Base64 {
    static _keyStr: string;
    static encode(input: any): string;
    static decode(input: any): string;
    static _utf8_encode(string: any): string;
    static _utf8_decode(utftext: any): string;
}
declare class WeatherFactory {
    static _weatherFlower: any;
    static getFlower(): any;
    static enabled: boolean;
    static weatherFBList: any[];
    static weatherSceneList: any[];
    static weatherRunlist: {};
}
declare class WeatherFlower extends WeatherBase {
    MAX_COUNT: number;
    r_P_List: RainLine[];
    r_R_List: any[];
    r_Max: number;
    r_L_Delay: number;
    r_L_Last_Time: number;
    r_R_Delay: number;
    r_R_Last_Time: number;
    s_C_Delay: number;
    s_C_Last_Time: number;
    timerFrame: number;
    stageTarget: any;
    _lastTime: any;
    constructor();
    setStageTarget(t: any): void;
    onWeatherStart(): void;
    onWeatherUpdate(): void;
    onWeatherStop(): void;
    private Remove(e);
}
