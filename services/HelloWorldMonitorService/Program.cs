using HelloWorldMonitorService;

var host = Host.CreateDefaultBuilder(args)
    .UseWindowsService()
    .ConfigureServices((context, services) =>
    {
        services.Configure<AppSettings>(context.Configuration.GetSection("AppSettings"));
        services.AddHostedService<Worker>();
    })
    .Build();
host.Run();
