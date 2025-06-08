var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Configure the HTTP request pipeline.
app.MapGet("/", () => "Hello, Eurofins!");

app.Run();