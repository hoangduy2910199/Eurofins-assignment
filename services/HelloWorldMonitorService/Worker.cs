namespace HelloWorldMonitorService;

using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private readonly HttpClient _httpClient = new();
    private readonly string _url;
    private readonly string _logPath;
    private readonly string _certPath;

    public Worker(ILogger<Worker> logger, IOptions<AppSettings> options)
    {
        _logger = logger;
        _url = options.Value.Url;
        _logPath = Path.Combine(AppContext.BaseDirectory, options.Value.LogPath);
        _certPath = options.Value.CertPath;
        var expectedCert = new X509Certificate2(_certPath);
        var handler = new HttpClientHandler
        {
            ServerCertificateCustomValidationCallback = (request, cert, chain, errors) =>
            {
                if (errors == SslPolicyErrors.None) return true;

                // Validate by thumbprint or public key hash
                return cert != null && cert.GetCertHashString() == expectedCert.GetCertHashString();
            }
        };
        _httpClient = new HttpClient(handler);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var response = await _httpClient.GetAsync(_url, stoppingToken);
                var status = $"{DateTime.Now}: {(int)response.StatusCode} {response.ReasonPhrase}";
                File.AppendAllText(_logPath, status + Environment.NewLine);
                _logger.LogInformation(status);

                if (response.StatusCode != HttpStatusCode.OK)
                {
                    _logger.LogError("Status not OK. Exiting.");
                    Environment.Exit(1);
                }
            }
            catch (Exception ex)
            {   
                await StopAsync(stoppingToken);
                var log = $"{DateTime.Now}: Error - {ex.Message}";
                File.AppendAllText(_logPath, log + Environment.NewLine);
                _logger.LogError(ex, "Exception occurred.");
                Environment.Exit(1);
            }

            await Task.Delay(TimeSpan.FromSeconds(60), stoppingToken);
        }
    }
}
