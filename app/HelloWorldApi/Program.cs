var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Configure the HTTP request pipelines.
app.MapGet("/", () => "Hello, Eurofins!");

app.Run();