using Microsoft.Azure.Cosmos;

namespace ContosoTraders.Api.Core.Repositories.Implementations;

public class CartRepository : CosmosGenericRepositoryBase<CartDao>, ICartRepository
{
    public CartRepository(IEnumerable<Database> cosmosDatabases, IConfiguration configuration)
        : base(cosmosDatabases.Single(db => db.Id == configuration[KeyVaultConstants.SecretNameCartsDbName]), configuration[KeyVaultConstants.SecretNameCartsDbContainerName])
    {
    }
}