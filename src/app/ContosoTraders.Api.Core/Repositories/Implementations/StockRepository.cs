using Microsoft.Azure.Cosmos;

namespace ContosoTraders.Api.Core.Repositories.Implementations;

public class StockRepository : CosmosGenericRepositoryBase<StockDao>, IStockRepository
{
    public StockRepository(IEnumerable<Database> cosmosDatabases, IConfiguration configuration)
        : base(cosmosDatabases.Single(db => db.Id == configuration[KeyVaultConstants.SecretNameStocksDbName]), configuration[KeyVaultConstants.SecretNameStocksDbContainerName])
    {
    }
}